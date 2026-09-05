import Combine
import Foundation

@MainActor
final class ConnectionCredentials: ObservableObject {
    @Published var password = ""
    @Published private(set) var errorMessage: String?
    private let store: any RemotePasswordStoring

    init(store: any RemotePasswordStoring = KeychainPasswordStore()) {
        self.store = store
    }

    func load(for key: RemoteCredentialKey, rememberPassword: Bool) {
        // Never carry one Mac/account's password into another connection form.
        password = ""
        errorMessage = nil
        guard rememberPassword else { return }
        do {
            password = try store.password(for: key) ?? ""
        } catch {
            errorMessage = "Couldn’t load the saved password. You can enter it again."
        }
    }

    @discardableResult
    func forget(for key: RemoteCredentialKey) -> Bool {
        do {
            try store.removePassword(for: key)
            errorMessage = nil
            // Keep the current form entry usable for this connection only.
            return true
        } catch {
            errorMessage = "Couldn’t remove the saved password. Please try again."
            return false
        }
    }
}
