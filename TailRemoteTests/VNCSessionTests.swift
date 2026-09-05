import Combine
import XCTest
@testable import RoyalVNCKit
@testable import TailRemote

@MainActor
final class VNCSessionTests: XCTestCase {
    private var connections: [VNCConnection] = []
    private var session: VNCSession!
    private var passwordStore: TestPasswordStore!

    override func setUp() async throws {
        connections = []
        passwordStore = TestPasswordStore()
        // Use real connection/framebuffer objects, with no network connection.
        session = VNCSession(passwordStore: passwordStore) { [weak self] in self?.connections.append($0) }
    }

    override func tearDown() async throws {
        session.disconnect()
        await drainCallbacks()
        session = nil
        connections = []
    }

    func testStartupStaysLoadingUntilFirstImageArrives() async throws {
        let connection = connect()
        XCTAssertEqual(session.state, .connecting)
        XCTAssertTrue(session.showsRemoteScreen)

        let credential = await credential(from: connection)
        XCTAssertNotNil(credential)
        XCTAssertEqual(session.state, .authenticating)

        session.connection(connection, stateDidChange: .connected)
        await drainCallbacks()
        XCTAssertEqual(session.state, .loadingDesktop)
        XCTAssertNil(session.framebufferImage)

        let framebuffer = try makeFramebuffer(for: connection)
        session.connection(connection, didCreateFramebuffer: framebuffer)
        await drainCallbacks()
        XCTAssertNil(session.framebufferImage, "An allocated buffer is not a received desktop")

        fill(framebuffer)
        sendFrameUpdate(framebuffer, from: connection)
        await drainCallbacks()
        XCTAssertEqual(session.state, .connected)
        XCTAssertNotNil(session.framebufferImage)
        XCTAssertEqual(session.framebufferImage?.width, 32)
    }

    func testQueuedOldDisconnectCannotEndNewConnectionOrClearItsPassword() async {
        let old = connect()
        session.connection(old, stateDidChange: .disconnected)
        let current = connect()
        session.connection(current, stateDidChange: .connected)
        await drainCallbacks()

        XCTAssertEqual(session.state, .loadingDesktop)
        let currentCredential = await credential(from: current) as? VNCUsernamePasswordCredential
        XCTAssertEqual(currentCredential?.password, "synthetic-test-password")
        let staleCredential = await credential(from: old)
        XCTAssertNil(staleCredential, "An old handshake must not receive the new connection's credentials")
    }

    func testOldFramebufferCallbacksCannotReplaceNewDesktop() async throws {
        let old = connect()
        let staleFrame = try makeFramebuffer(for: old, width: 64)
        fill(staleFrame)
        session.connection(old, didCreateFramebuffer: staleFrame)
        session.connection(old, didResizeFramebuffer: staleFrame)
        sendFrameUpdate(staleFrame, from: old)
        _ = connect()
        await drainCallbacks()

        XCTAssertEqual(session.state, .connecting)
        XCTAssertEqual(session.framebufferSize, .zero)
        XCTAssertNil(session.framebufferImage)
    }

    func testCancelledConnectionIgnoresLateConnectedAndFrameCallbacks() async throws {
        let connection = connect()
        let framebuffer = try makeFramebuffer(for: connection)
        fill(framebuffer)
        session.disconnect()
        session.connection(connection, stateDidChange: .connected)
        sendFrameUpdate(framebuffer, from: connection)
        await drainCallbacks()

        XCTAssertEqual(session.state, .disconnected)
        XCTAssertFalse(session.showsRemoteScreen)
        XCTAssertNil(session.framebufferImage)
        let cancelledCredential = await credential(from: connection)
        XCTAssertNil(cancelledCredential)
    }

    func testLateCreationCallbackDoesNotClearAnAlreadyPresentedFrame() async throws {
        let connection = connect()
        let framebuffer = try makeFramebuffer(for: connection)
        fill(framebuffer)
        sendFrameUpdate(framebuffer, from: connection)
        await drainCallbacks()
        XCTAssertNotNil(session.framebufferImage)

        session.connection(connection, didCreateFramebuffer: framebuffer)
        session.connection(connection, stateDidChange: .connected)
        await drainCallbacks()
        XCTAssertNotNil(session.framebufferImage)
        XCTAssertEqual(session.state, .connected)
    }

    func testPasswordIsSavedOnlyAfterAuthenticationAndOnlyOnce() async {
        let connection = connect(rememberPassword: true)
        _ = await credential(from: connection)
        XCTAssertEqual(passwordStore.saveCount, 0)
        session.connection(connection, stateDidChange: .connected)
        await drainCallbacks()
        XCTAssertEqual(passwordStore.saveCount, 1)
        XCTAssertEqual(passwordStore.passwords[savedKey], "synthetic-test-password")
        session.connection(connection, stateDidChange: .connected)
        await drainCallbacks()
        XCTAssertEqual(passwordStore.saveCount, 1)
    }

    func testFailedSignInKeepsPreviouslySavedPassword() async {
        passwordStore.passwords[savedKey] = "previously-working-password"
        let connection = connect(rememberPassword: true)
        session.connection(connection, stateDidChange: .disconnected)
        await drainCallbacks()
        XCTAssertEqual(passwordStore.saveCount, 0)
        XCTAssertEqual(passwordStore.passwords[savedKey], "previously-working-password")
    }

    func testRememberDisabledNeverSavesPassword() async {
        let connection = connect(rememberPassword: false)
        session.connection(connection, stateDidChange: .connected)
        await drainCallbacks()
        XCTAssertEqual(passwordStore.saveCount, 0)
        XCTAssertTrue(passwordStore.passwords.isEmpty)
    }

    func testStaleSuccessfulConnectionCannotSaveCredentials() async {
        let old = connect(rememberPassword: true)
        session.connection(old, stateDidChange: .connected)
        _ = connect(rememberPassword: false)
        await drainCallbacks()
        XCTAssertEqual(passwordStore.saveCount, 0)
    }

    func testSaveFailureKeepsConnectionUsableAndReportsIt() async {
        passwordStore.shouldFail = true
        let connection = connect(rememberPassword: true)
        session.connection(connection, stateDidChange: .connected)
        await drainCallbacks()
        XCTAssertEqual(session.state, .loadingDesktop)
        XCTAssertNotNil(session.credentialStorageError)
        XCTAssertFalse(session.credentialStorageError?.contains("synthetic-test-password") ?? true)
    }

    private var savedKey: RemoteCredentialKey {
        RemoteCredentialKey(hostname: "test.invalid", port: 5900, username: "test-user")
    }

    private func connect(rememberPassword: Bool = false) -> VNCConnection {
        session.connect(hostname: "test.invalid", port: 5900, username: "test-user", password: "synthetic-test-password", rememberPassword: rememberPassword)
        return connections.last!
    }

    private func credential(from connection: VNCConnection) async -> VNCCredential? {
        await withCheckedContinuation { continuation in
            session.connection(connection, credentialFor: .appleRemoteDesktop) {
                continuation.resume(returning: $0)
            }
        }
    }

    private func makeFramebuffer(for connection: VNCConnection, width: UInt16 = 32) throws -> VNCFramebuffer {
        let framebuffer = try VNCFramebuffer(
            logger: connection.logger,
            size: VNCSize(width: width, height: 24),
            screens: [],
            pixelFormat: VNCProtocol.PixelFormat(depth: 24),
            allocator: VNCFramebufferMallocAllocator()
        )
        connection.framebuffer = framebuffer
        return framebuffer
    }

    private func fill(_ framebuffer: VNCFramebuffer) {
        var pixel = Data([0x33, 0x66, 0x99, 0])
        framebuffer.fill(region: framebuffer.fullRegion, withPixel: &pixel)
    }

    private func sendFrameUpdate(_ framebuffer: VNCFramebuffer, from connection: VNCConnection) {
        session.connection(connection, didUpdateFramebuffer: framebuffer, x: 0, y: 0, width: framebuffer.size.width, height: framebuffer.size.height)
    }

    private func drainCallbacks() async {
        // Let MainActor process the queued delegate callbacks and display work.
        let drained = expectation(description: "Queued callbacks processed")
        DispatchQueue.main.async { drained.fulfill() }
        await fulfillment(of: [drained], timeout: 2)
    }
}
