import Combine
import CoreGraphics
import Foundation
import OSLog
import QuartzCore
import RoyalVNCKit

enum RemoteConnectionState: Equatable {
    case idle
    case connecting
    case authenticating
    case loadingDesktop
    case connected
    case disconnecting
    case disconnected

    var statusText: String {
        switch self {
        case .idle: return "Ready"
        case .connecting: return "Connecting"
        case .authenticating: return "Signing in"
        case .loadingDesktop: return "Loading desktop"
        case .connected: return "Connected"
        case .disconnecting: return "Disconnecting"
        case .disconnected: return "Disconnected"
        }
    }
}

@MainActor
final class VNCSession: NSObject, ObservableObject, VNCConnectionDelegate, RemoteCanvasInput {
    @Published private(set) var state: RemoteConnectionState = .idle
    @Published private(set) var framebufferImage: CGImage?
    @Published private(set) var framebufferSize: CGSize = .zero
    @Published private(set) var cursorPoint: CGPoint = .zero
    @Published private(set) var lastError: String?
    @Published private(set) var credentialStorageError: String?
    let clickFeedback = PassthroughSubject<RemoteClickFeedback, Never>()

    private var connection: VNCConnection?
    private var framebuffer: VNCFramebuffer?
    private var username = ""
    private var password = ""
    private let passwordStore: any RemotePasswordStoring
    private var passwordKeyToSave: RemoteCredentialKey?
    private var cursorIsInitialized = false
    private var hasPendingFrame = false
    private var displayLink: CADisplayLink?
    private let startConnection: (VNCConnection) -> Void
    private var connectionStartedAt: CFTimeInterval?
    private let connectionLogger = Logger(subsystem: "TailRemote", category: "Connection")

    init(
        passwordStore: any RemotePasswordStoring = KeychainPasswordStore(),
        startConnection: @escaping (VNCConnection) -> Void = { $0.connect() }
    ) {
        self.passwordStore = passwordStore
        self.startConnection = startConnection
        super.init()
    }

    var showsRemoteScreen: Bool {
        switch state {
        case .connecting, .authenticating, .loadingDesktop, .connected, .disconnecting:
            return true
        case .idle, .disconnected:
            return false
        }
    }

    func connect(hostname: String, port: UInt16, username: String, password: String, rememberPassword: Bool = false) {
        // An old connection may still have delegate tasks queued on MainActor.
        // Detach it before disconnecting, and check identity in every callback.
        connection?.delegate = nil
        connection?.disconnect()
        stopDisplayLink()
        connectionStartedAt = CACurrentMediaTime()

        self.username = username
        self.password = password
        passwordKeyToSave = rememberPassword
            ? RemoteCredentialKey(hostname: hostname, port: port, username: username)
            : nil
        credentialStorageError = nil
        lastError = nil
        framebuffer = nil
        framebufferImage = nil
        framebufferSize = .zero
        cursorPoint = .zero
        cursorIsInitialized = false
        hasPendingFrame = false

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
        updateState(.connecting)
        startConnection(connection)
    }

    func disconnect() {
        guard let connection else {
            updateState(.disconnected)
            return
        }
        updateState(.disconnecting)
        stopDisplayLink()
        hasPendingFrame = false
        connection.disconnect()
    }

    func movePointer(viewDelta: CGPoint, viewSize: CGSize, zoomScale: CGFloat = RemoteGeometry.minimumZoomScale) {
        initializeCursorIfNeeded()
        let framebufferDelta = RemoteGeometry.framebufferDelta(
            fromViewDelta: viewDelta,
            framebufferSize: framebufferSize,
            viewSize: viewSize,
            zoomScale: zoomScale
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
        if state == .connected, connection != nil {
            clickFeedback.send(RemoteClickFeedback(point: cursorPoint, button: button, count: count))
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
        guard displayLink == nil else { return }
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
        guard hasPendingFrame, let framebuffer, let image = framebuffer.cgImage else { return }
        hasPendingFrame = false
        framebufferImage = image
        updateState(.connected)
    }

    private func updateState(_ newState: RemoteConnectionState) {
        guard state != newState else { return }
        state = newState
        if let connectionStartedAt {
            let elapsed = CACurrentMediaTime() - connectionStartedAt
            // Only fixed stage names and elapsed time, never hosts or credentials.
            connectionLogger.info("\(newState.statusText, privacy: .public) after \(elapsed, privacy: .public) seconds")
        }
    }

    private func acceptsCallbacks(from connection: VNCConnection) -> Bool {
        self.connection === connection && state != .disconnecting && state != .disconnected
    }

    private func saveAuthenticatedPassword() {
        guard let key = passwordKeyToSave else { return }
        passwordKeyToSave = nil
        do {
            try passwordStore.save(password, for: key)
        } catch {
            credentialStorageError = "Connected, but the password couldn’t be saved on this iPhone."
        }
    }

    private func adoptFramebuffer(_ framebuffer: VNCFramebuffer) {
        guard self.framebuffer !== framebuffer else { return }
        self.framebuffer = framebuffer
        framebufferSize = framebuffer.cgSize
        framebufferImage = nil
        hasPendingFrame = false
        if cursorIsInitialized {
            cursorPoint = RemoteGeometry.clamp(cursorPoint, to: framebufferSize)
        } else {
            initializeCursorIfNeeded()
        }
        updateState(.loadingDesktop)
    }

    nonisolated func connection(
        _ connection: VNCConnection,
        stateDidChange connectionState: VNCConnection.ConnectionState
    ) {
        Task { @MainActor [weak self] in
            guard let self, self.connection === connection else { return }
            switch connectionState.status {
            case .connecting:
                break
            case .connected:
                guard self.acceptsCallbacks(from: connection) else { return }
                self.saveAuthenticatedPassword()
                self.updateState(self.framebufferImage == nil ? .loadingDesktop : .connected)
            case .disconnecting:
                self.updateState(.disconnecting)
                self.stopDisplayLink()
                self.hasPendingFrame = false
            case .disconnected:
                if let error = connectionState.error as? VNCError, error.shouldDisplayToUser {
                    self.lastError = error.localizedDescription
                } else if let error = connectionState.error {
                    self.lastError = error.localizedDescription
                }
                self.updateState(.disconnected)
                self.stopDisplayLink()
                self.connection?.delegate = nil
                self.connection = nil
                self.framebuffer = nil
                self.framebufferImage = nil
                self.hasPendingFrame = false
                self.password = ""
                self.passwordKeyToSave = nil
                self.connectionStartedAt = nil
            }
        }
    }

    nonisolated func connection(
        _ connection: VNCConnection,
        credentialFor authenticationType: VNCAuthenticationType,
        completion: @escaping (VNCCredential?) -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let self, self.acceptsCallbacks(from: connection) else {
                completion(nil)
                return
            }

            guard !self.password.isEmpty else {
                completion(nil)
                return
            }

            if self.state == .connecting {
                self.updateState(.authenticating)
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
        Task { @MainActor [weak self] in
            guard let self, self.acceptsCallbacks(from: connection),
                  connection.framebuffer === framebuffer else { return }
            self.adoptFramebuffer(framebuffer)
        }
    }

    nonisolated func connection(
        _ connection: VNCConnection,
        didResizeFramebuffer framebuffer: VNCFramebuffer
    ) {
        Task { @MainActor [weak self] in
            guard let self, self.acceptsCallbacks(from: connection),
                  connection.framebuffer === framebuffer else { return }
            self.adoptFramebuffer(framebuffer)
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
            guard let self, self.acceptsCallbacks(from: connection),
                  connection.framebuffer === framebuffer else { return }
            self.adoptFramebuffer(framebuffer)
            self.hasPendingFrame = true
            if self.framebufferImage == nil {
                // Present the first available image immediately. Later updates
                // stay coalesced to the display cadence.
                self.displayLinkFired()
                self.startDisplayLink()
            }
        }
    }

    nonisolated func connection(_ connection: VNCConnection, didUpdateCursor cursor: VNCCursor) {
        // macOS Screen Sharing generally expects the client to draw its own pointer.
    }
}
