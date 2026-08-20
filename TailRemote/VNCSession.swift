import CoreGraphics
import Foundation
import QuartzCore
import RoyalVNCKit

enum RemoteConnectionState: Equatable {
    case idle
    case connecting
    case connected
    case disconnecting
    case disconnected

    var statusText: String {
        switch self {
        case .idle: return "Ready"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        case .disconnecting: return "Disconnecting"
        case .disconnected: return "Disconnected"
        }
    }
}

@MainActor
final class VNCSession: NSObject, ObservableObject, VNCConnectionDelegate {
    @Published private(set) var state: RemoteConnectionState = .idle
    @Published private(set) var framebufferImage: CGImage?
    @Published private(set) var framebufferSize: CGSize = .zero
    @Published private(set) var cursorPoint: CGPoint = .zero
    @Published private(set) var lastError: String?

    private var connection: VNCConnection?
    private var framebuffer: VNCFramebuffer?
    private var username = ""
    private var password = ""
    private var cursorIsInitialized = false
    private var hasPendingFrame = false
    private var displayLink: CADisplayLink?

    var showsRemoteScreen: Bool {
        switch state {
        case .connecting, .connected, .disconnecting:
            return true
        case .idle, .disconnected:
            return false
        }
    }

    func connect(hostname: String, port: UInt16, username: String, password: String) {
        connection?.disconnect()
        stopDisplayLink()

        self.username = username
        self.password = password
        lastError = nil
        framebuffer = nil
        framebufferImage = nil
        framebufferSize = .zero
        cursorPoint = .zero
        cursorIsInitialized = false

        let settings = VNCConnection.Settings(
            isDebugLoggingEnabled: false,
            hostname: hostname,
            port: port,
            isShared: true,
            isScalingEnabled: false,
            useDisplayLink: false,
            inputMode: .forwardKeyboardShortcutsIfNotInUseLocally,
            isClipboardRedirectionEnabled: true,
            colorDepth: .depth24Bit,
            frameEncodings: .default
        )

        let connection = VNCConnection(settings: settings)
        connection.delegate = self
        self.connection = connection
        state = .connecting
        startDisplayLink()
        connection.connect()
    }

    func disconnect() {
        guard let connection else {
            state = .disconnected
            return
        }
        state = .disconnecting
        connection.disconnect()
    }

    func movePointer(viewDelta: CGPoint, viewSize: CGSize) {
        initializeCursorIfNeeded()
        let framebufferDelta = RemoteGeometry.framebufferDelta(
            fromViewDelta: viewDelta,
            framebufferSize: framebufferSize,
            viewSize: viewSize
        )
        cursorPoint = RemoteGeometry.clamp(
            CGPoint(x: cursorPoint.x + framebufferDelta.x, y: cursorPoint.y + framebufferDelta.y),
            to: framebufferSize
        )
        connection?.mouseMove(x: UInt16(cursorPoint.x), y: UInt16(cursorPoint.y))
    }

    func mouseDown(_ button: VNCMouseButton) {
        initializeCursorIfNeeded()
        connection?.mouseButtonDown(button, x: UInt16(cursorPoint.x), y: UInt16(cursorPoint.y))
    }

    func mouseUp(_ button: VNCMouseButton) {
        initializeCursorIfNeeded()
        connection?.mouseButtonUp(button, x: UInt16(cursorPoint.x), y: UInt16(cursorPoint.y))
    }

    func click(_ button: VNCMouseButton, count: Int = 1) {
        for _ in 0..<max(count, 1) {
            mouseDown(button)
            mouseUp(button)
        }
    }

    func scroll(_ wheel: VNCMouseWheel, steps: UInt32) {
        initializeCursorIfNeeded()
        connection?.mouseWheel(
            wheel,
            x: UInt16(cursorPoint.x),
            y: UInt16(cursorPoint.y),
            steps: max(steps, 1)
        )
    }

    func sendText(_ text: String) {
        for character in text {
            if character.isNewline {
                pressKey(.return)
            } else {
                VNCKeyCode.withCharacter(character).forEach(pressKey)
            }
        }
    }

    func pressKey(_ key: VNCKeyCode) {
        connection?.keyDown(key)
        connection?.keyUp(key)
    }

    private func initializeCursorIfNeeded() {
        guard !cursorIsInitialized, framebufferSize.width > 0, framebufferSize.height > 0 else { return }
        cursorPoint = CGPoint(x: framebufferSize.width / 2, y: framebufferSize.height / 2)
        cursorIsInitialized = true
        connection?.mouseMove(x: UInt16(cursorPoint.x), y: UInt16(cursorPoint.y))
    }

    private func startDisplayLink() {
        let link = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 60, preferred: 30)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkFired() {
        guard hasPendingFrame, let framebuffer else { return }
        hasPendingFrame = false
        framebufferImage = framebuffer.cgImage
    }

    nonisolated func connection(
        _ connection: VNCConnection,
        stateDidChange connectionState: VNCConnection.ConnectionState
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch connectionState.status {
            case .connecting:
                self.state = .connecting
            case .connected:
                self.state = .connected
            case .disconnecting:
                self.state = .disconnecting
            case .disconnected:
                if let error = connectionState.error as? VNCError, error.shouldDisplayToUser {
                    self.lastError = error.localizedDescription
                } else if let error = connectionState.error {
                    self.lastError = error.localizedDescription
                }
                self.state = .disconnected
                self.stopDisplayLink()
                self.connection?.delegate = nil
                self.connection = nil
                self.framebuffer = nil
                self.framebufferImage = nil
                self.password = ""
            }
        }
    }

    nonisolated func connection(
        _ connection: VNCConnection,
        credentialFor authenticationType: VNCAuthenticationType,
        completion: @escaping (VNCCredential?) -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let self else {
                completion(nil)
                return
            }

            guard !self.password.isEmpty else {
                completion(nil)
                return
            }

            if authenticationType.requiresUsername, !self.username.isEmpty {
                completion(VNCUsernamePasswordCredential(username: self.username, password: self.password))
            } else if authenticationType.requiresPassword {
                completion(VNCPasswordCredential(password: self.password))
            } else {
                completion(nil)
            }
        }
    }

    nonisolated func connection(
        _ connection: VNCConnection,
        didCreateFramebuffer framebuffer: VNCFramebuffer
    ) {
        let size = framebuffer.cgSize
        let image = framebuffer.cgImage
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.framebuffer = framebuffer
            self.framebufferSize = size
            self.framebufferImage = image
            self.initializeCursorIfNeeded()
        }
    }

    nonisolated func connection(
        _ connection: VNCConnection,
        didResizeFramebuffer framebuffer: VNCFramebuffer
    ) {
        let size = framebuffer.cgSize
        let image = framebuffer.cgImage
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.framebuffer = framebuffer
            self.framebufferSize = size
            self.framebufferImage = image
            self.cursorPoint = RemoteGeometry.clamp(self.cursorPoint, to: size)
        }
    }

    nonisolated func connection(
        _ connection: VNCConnection,
        didUpdateFramebuffer framebuffer: VNCFramebuffer,
        x: UInt16,
        y: UInt16,
        width: UInt16,
        height: UInt16
    ) {
        Task { @MainActor [weak self] in
            self?.hasPendingFrame = true
        }
    }

    nonisolated func connection(_ connection: VNCConnection, didUpdateCursor cursor: VNCCursor) {
        // macOS Screen Sharing generally expects the client to draw its own pointer.
    }
}
