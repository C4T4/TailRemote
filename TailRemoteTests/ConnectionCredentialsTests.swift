import XCTest
@testable import TailRemote

@MainActor
final class ConnectionCredentialsTests: XCTestCase {
    private let key = RemoteCredentialKey(hostname: "mac.test.invalid", port: 5900, username: "test-user")

    func testReopeningFormRestoresSavedPassword() async {
        let store = TestPasswordStore()
        store.passwords[key] = "synthetic-password"
        let form = ConnectionCredentials(store: store)
        form.load(for: key, rememberPassword: true)
        XCTAssertEqual(form.password, "synthetic-password")
        let reopened = ConnectionCredentials(store: store)
        reopened.load(for: key, rememberPassword: true)
        XCTAssertEqual(reopened.password, "synthetic-password")
    }

    func testChangingMacOrDisablingRememberCannotReusePreviousPassword() async {
        let store = TestPasswordStore()
        store.passwords[key] = "synthetic-password"
        let form = ConnectionCredentials(store: store)
        form.load(for: key, rememberPassword: true)
        let other = RemoteCredentialKey(hostname: "other.test.invalid", port: 5900, username: key.username)
        form.load(for: other, rememberPassword: true)
        XCTAssertTrue(form.password.isEmpty)
        form.load(for: key, rememberPassword: true)
        form.load(for: key, rememberPassword: false)
        XCTAssertTrue(form.password.isEmpty)
    }

    func testReadFailureClearsPreviousPasswordAndExplainsError() async {
        let store = TestPasswordStore()
        store.passwords[key] = "synthetic-password"
        let form = ConnectionCredentials(store: store)
        form.load(for: key, rememberPassword: true)
        store.shouldFail = true
        form.load(for: key, rememberPassword: true)
        XCTAssertTrue(form.password.isEmpty)
        XCTAssertNotNil(form.errorMessage)
    }

    func testForgettingRemovesSavedCopyButKeepsCurrentEntryUsable() async {
        let store = TestPasswordStore()
        store.passwords[key] = "synthetic-password"
        let form = ConnectionCredentials(store: store)
        form.load(for: key, rememberPassword: true)
        XCTAssertTrue(form.forget(for: key))
        XCTAssertNil(store.passwords[key])
        XCTAssertEqual(form.password, "synthetic-password")
        form.load(for: key, rememberPassword: true)
        XCTAssertTrue(form.password.isEmpty)
    }

    func testFailedRemovalDoesNotClaimPasswordWasForgotten() async {
        let store = TestPasswordStore()
        store.passwords[key] = "synthetic-password"
        let form = ConnectionCredentials(store: store)
        store.shouldFail = true
        XCTAssertFalse(form.forget(for: key))
        XCTAssertNotNil(store.passwords[key])
        XCTAssertNotNil(form.errorMessage)
    }
}
