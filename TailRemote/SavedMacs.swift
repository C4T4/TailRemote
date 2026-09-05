import Combine
import Foundation

struct SavedMac: Codable, Identifiable, Equatable {
    var hostname: String
    var name: String
    var username: String
    var aliases: [String] = []

    var id: String { Self.normalize(hostname) }
    var addresses: Set<String> { Set(([hostname] + aliases).map(Self.normalize)) }

    static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct MacImport: Codable {
    let version: Int
    let macs: [SavedMac]
}

@MainActor
final class SavedMacs: ObservableObject {
    @Published private(set) var macs: [SavedMac]
    private let defaults: UserDefaults
    private static let storageKey = "savedMacs.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        macs = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode([SavedMac].self, from: $0) } ?? []
    }

    func matching(_ hostname: String) -> SavedMac? {
        let address = SavedMac.normalize(hostname)
        return macs.first { $0.addresses.contains(address) }
    }

    func remember(hostname: String, username: String, name: String? = nil) {
        let host = SavedMac.normalize(hostname)
        guard !host.isEmpty else { return }
        if let index = macs.firstIndex(where: { $0.addresses.contains(host) }) {
            macs[index].username = username.trimmingCharacters(in: .whitespacesAndNewlines)
            if let name, !name.isEmpty { macs[index].name = name }
        } else {
            macs.append(SavedMac(hostname: host, name: name ?? host, username: username))
        }
        persist()
    }

    // Preserve the endpoint and account already used by the app so an import
    // cannot detach existing Keychain credentials or replace a user's account.
    func importMacs(_ data: Data) throws {
        guard data.count <= 1_048_576 else { throw ImportError.invalidFile }
        let imported = try JSONDecoder().decode(MacImport.self, from: data)
        guard imported.version == 1, !imported.macs.isEmpty,
              imported.macs.count <= 256,
              imported.macs.allSatisfy(Self.isValid) else { throw ImportError.invalidFile }
        for var mac in imported.macs {
            mac.hostname = SavedMac.normalize(mac.hostname)
            mac.name = mac.name.trimmingCharacters(in: .whitespacesAndNewlines)
            mac.username = mac.username.trimmingCharacters(in: .whitespacesAndNewlines)
            if let index = macs.firstIndex(where: { !$0.addresses.isDisjoint(with: mac.addresses) }) {
                let existing = macs[index]
                let allAddresses = existing.addresses.union(mac.addresses)
                mac.hostname = existing.hostname
                mac.aliases = Array(allAddresses).sorted()
                if !existing.username.isEmpty { mac.username = existing.username }
                macs[index] = mac
            } else {
                macs.append(mac)
            }
        }
        persist()
    }

    func importPendingFile(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        // Bound the read as well as the decoder to avoid loading an arbitrary file.
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try importMacs(handle.read(upToCount: 1_048_577) ?? Data())
        try FileManager.default.removeItem(at: url)
    }

    static func isValid(_ mac: SavedMac) -> Bool {
        func validAddress(_ value: String) -> Bool {
            let address = SavedMac.normalize(value)
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-:")
            return !address.isEmpty && address.count <= 253
                && address.unicodeScalars.allSatisfy { allowed.contains($0) }
        }
        return validAddress(mac.hostname) && mac.aliases.count <= 32
            && mac.aliases.allSatisfy(validAddress)
            && !mac.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && mac.name.count <= 128 && mac.username.count <= 128
            && !mac.name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
            && !mac.username.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(macs) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    enum ImportError: Error { case invalidFile }
}
