import SwiftUI

@main
struct TailRemoteApp: App {
    @StateObject private var session = VNCSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .preferredColorScheme(.dark)
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var session: VNCSession

    var body: some View {
        Group {
            if session.showsRemoteScreen {
                RemoteDesktopView()
            } else {
                ConnectView()
            }
        }
        .animation(.easeInOut(duration: 0.22), value: session.showsRemoteScreen)
    }
}

