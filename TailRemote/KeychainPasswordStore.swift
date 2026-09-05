import Foundation
import Security

struct RemoteCredentialKey: Equatable, Hashable {
    let hostname: String
    let port: UInt16
    let username: String

    init(hostname: String, port: UInt16, username: String) {
        self.hostname = hostname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.port = port
        self.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var account: String {
        // Array encoding keeps host/port/user boundaries unambiguous.
        let components = [hostname, String(port), username]
        return (try! JSONEncoder().encode(components)).base64EncodedString()
    }
}

protocol RemotePasswordStoring {
    func password(for key: RemoteCredentialKey) throws -> String?
    func save(_ password: String, for key: RemoteCredentialKey) throws
    func removePassword(for key: RemoteCredentialKey) throws
}

struct KeychainPasswordStore: RemotePasswordStoring {
    let service: String

    init(service: String = (Bundle.main.bundleIdentifier ?? "TailRemote") + ".remote-passwords.v1") {
        self.service = service
    }

    func password(for key: RemoteCredentialKey) throws -> String? {
        var request = query(for: key)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        guard let data = result as? Data, let password = String(data: data, encoding: .utf8) else {
            throw KeychainError(status: errSecDecode)
        }
        return password
    }

    func save(_ password: String, for key: RemoteCredentialKey) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: Data(password.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let request = query(for: key)
        var status = SecItemUpdate(request as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let item = request.merging(attributes) { _, new in new }
            status = SecItemAdd(item as CFDictionary, nil)
            if status == errSecDuplicateItem {
                status = SecItemUpdate(request as CFDictionary, attributes as CFDictionary)
            }
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    func removePassword(for key: RemoteCredentialKey) throws {
        let status = SecItemDelete(query(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    private func query(for key: RemoteCredentialKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.account,
            kSecAttrSynchronizable as String: false
        ]
    }
}

struct KeychainError: Error {
    let status: OSStatus
}
