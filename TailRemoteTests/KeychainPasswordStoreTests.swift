import Security
import XCTest
@testable import TailRemote

final class KeychainPasswordStoreTests: XCTestCase {
    private var store: KeychainPasswordStore!
    private let key = RemoteCredentialKey(hostname: "mac.test.invalid", port: 5900, username: "test-user")

    override func setUp() {
        store = KeychainPasswordStore(service: "TailRemote.tests.\(UUID().uuidString)")
    }

    override func tearDown() {
        // Remove only this test's randomly isolated Keychain service.
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: store.service
        ] as CFDictionary)
    }

    func testSavedPasswordSurvivesStoreRecreationAndCanBeUpdated() throws {
        XCTAssertNil(try store.password(for: key))
        try store.save("synthetic-pässword-🔑", for: key)
        let reopened = KeychainPasswordStore(service: store.service)
        XCTAssertEqual(try reopened.password(for: key), "synthetic-pässword-🔑")
        try reopened.save("synthetic-replacement", for: key)
        XCTAssertEqual(try store.password(for: key), "synthetic-replacement")
    }

    func testPasswordsAreScopedToHostPortAndUsername() throws {
        try store.save("synthetic-password", for: key)
        let sameAccount = RemoteCredentialKey(hostname: " MAC.TEST.INVALID\n", port: 5900, username: " test-user ")
        XCTAssertEqual(try store.password(for: sameAccount), "synthetic-password")
        for other in [
            RemoteCredentialKey(hostname: "other.test.invalid", port: 5900, username: "test-user"),
            RemoteCredentialKey(hostname: key.hostname, port: 5901, username: key.username),
            RemoteCredentialKey(hostname: key.hostname, port: key.port, username: "other-user")
        ] {
            XCTAssertNil(try store.password(for: other))
        }
    }

    func testRemovalIsScopedAndIdempotent() throws {
        let other = RemoteCredentialKey(hostname: "other.test.invalid", port: 5900, username: "test-user")
        try store.save("synthetic-first", for: key)
        try store.save("synthetic-second", for: other)
        try store.removePassword(for: key)
        try store.removePassword(for: key)
        XCTAssertNil(try store.password(for: key))
        XCTAssertEqual(try store.password(for: other), "synthetic-second")
    }

    func testPasswordIsDeviceLocalAndOnlyAccessibleWhenUnlocked() throws {
        try store.save("synthetic-password", for: key)
        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: store.service,
            kSecAttrAccount as String: key.account,
            kSecReturnAttributes as String: true
        ] as CFDictionary, &result)
        XCTAssertEqual(status, errSecSuccess)
        let attributes = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(attributes[kSecAttrAccessible as String] as? String, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        XCTAssertNotEqual(attributes[kSecAttrSynchronizable as String] as? Bool, true)
        XCTAssertNil(attributes[kSecValueData as String])
    }
}

final class TestPasswordStore: RemotePasswordStoring {
    var passwords: [RemoteCredentialKey: String] = [:]
    var saveCount = 0
    var shouldFail = false

    func password(for key: RemoteCredentialKey) throws -> String? {
        if shouldFail { throw KeychainError(status: errSecInteractionNotAllowed) }
        return passwords[key]
    }

    func save(_ password: String, for key: RemoteCredentialKey) throws {
        if shouldFail { throw KeychainError(status: errSecInteractionNotAllowed) }
        passwords[key] = password
        saveCount += 1
    }

    func removePassword(for key: RemoteCredentialKey) throws {
        if shouldFail { throw KeychainError(status: errSecInteractionNotAllowed) }
        passwords[key] = nil
    }
}
