#if DEBUG
@testable import RoyalVNCKit
import SwiftUI

// A separate defaults suite and Keychain service let UI tests exercise the real
// form and persistence across launches without accessing any user's credentials.
struct CredentialTestView: View {
    private static let defaults = UserDefaults(suiteName: "TailRemote.CredentialUITests")!
    private static let store = KeychainPasswordStore(service: "TailRemote.credential-ui-tests")
    private static let key = RemoteCredentialKey(hostname: "ui.test.invalid", port: 5900, username: "test-user")
    @StateObject private var session = makeSession()

    var body: some View {
        Group {
            if session.showsRemoteScreen {
                RemoteDesktopView()
            } else {
                ConnectView(passwordStore: Self.store, defaults: Self.defaults)
            }
        }
        .environmentObject(session)
        .defaultAppStorage(Self.defaults)
    }

    private static func makeSession() -> VNCSession {
        if ProcessInfo.processInfo.arguments.contains("--reset-credential-test") {
            defaults.removePersistentDomain(forName: "TailRemote.CredentialUITests")
            try? store.removePassword(for: key)
            defaults.set(key.hostname, forKey: "remoteHost")
            defaults.set(key.username, forKey: "remoteUsername")
            let macs = SavedMacs(defaults: defaults)
            macs.remember(hostname: key.hostname, username: key.username, name: "Test Mac")
            macs.remember(hostname: "other.test.invalid", username: "other-user", name: "Other Mac")
        }
        return VNCSession(passwordStore: store) { connection in
            // Simulate successful authentication; never open a network socket.
            connection.delegate?.connection(connection, stateDidChange: .connected)
        }
    }
}
#endif
