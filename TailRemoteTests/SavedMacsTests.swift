import XCTest
@testable import TailRemote

@MainActor
final class SavedMacsTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        suite = "SavedMacsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
    }

    private func data(_ macs: [SavedMac]) throws -> Data {
        try JSONEncoder().encode(MacImport(version: 1, macs: macs))
    }

    func testAccountsStayWithTheirMacAfterRelaunch() async {
        let store = SavedMacs(defaults: defaults)
        store.remember(hostname: "one.test.invalid", username: "first")
        store.remember(hostname: "two.test.invalid", username: "second")
        store.remember(hostname: "one.test.invalid", username: "updated")
        let reopened = SavedMacs(defaults: defaults)
        XCTAssertEqual(reopened.matching("one.test.invalid")?.username, "updated")
        XCTAssertEqual(reopened.matching("two.test.invalid")?.username, "second")
        XCTAssertEqual(reopened.macs.count, 2)
    }

    func testImportKeepsExistingCredentialKeyAndAccountAcrossAliases() async throws {
        let store = SavedMacs(defaults: defaults)
        store.remember(hostname: "100.64.0.1", username: "saved-user")
        let imported = SavedMac(hostname: "mac.test.invalid", name: "My Mac", username: "import-user", aliases: ["100.64.0.1", "mac"])
        try store.importMacs(data([imported]))
        try store.importMacs(data([imported]))
        XCTAssertEqual(store.macs.count, 1)
        let mac = try XCTUnwrap(store.matching("mac.test.invalid"))
        XCTAssertEqual(mac.hostname, "100.64.0.1")
        XCTAssertEqual(mac.username, "saved-user")
        XCTAssertEqual(mac.name, "My Mac")
        XCTAssertEqual(store.matching("mac"), mac)
    }

    func testImportFillsMissingUsernameWithoutInventingPeerAccount() async throws {
        let store = SavedMacs(defaults: defaults)
        store.remember(hostname: "local.test.invalid", username: "")
        try store.importMacs(data([
            SavedMac(hostname: "local.test.invalid", name: "Local Mac", username: "local-user"),
            SavedMac(hostname: "peer.test.invalid", name: "Peer Mac", username: "")
        ]))
        XCTAssertEqual(store.matching("local.test.invalid")?.username, "local-user")
        XCTAssertEqual(store.matching("peer.test.invalid")?.username, "")
    }

    func testInvalidImportIsAtomicAndCannotAddURLOrUserinfo() async throws {
        let store = SavedMacs(defaults: defaults)
        let valid = SavedMac(hostname: "mac.test.invalid", name: "Mac", username: "user")
        let invalid = SavedMac(hostname: "https://user:secret@host/path", name: "Invalid", username: "user")
        XCTAssertThrowsError(try store.importMacs(data([valid, invalid])))
        XCTAssertTrue(store.macs.isEmpty)
        XCTAssertThrowsError(try store.importMacs(Data(repeating: 32, count: 1_048_577)))
    }

    func testPendingFileImportsOnceAndPersistsAcrossRelaunch() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: file) }
        try data([SavedMac(hostname: "mac.test.invalid", name: "Mac", username: "user")]).write(to: file)
        let store = SavedMacs(defaults: defaults)
        try store.importPendingFile(at: file)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        try store.importPendingFile(at: file)
        XCTAssertEqual(SavedMacs(defaults: defaults).macs, store.macs)
    }
}
