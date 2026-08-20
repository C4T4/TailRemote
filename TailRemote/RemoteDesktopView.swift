import RoyalVNCKit
import SwiftUI

struct RemoteDesktopView: View {
    @EnvironmentObject private var session: VNCSession
    @State private var keyboardIsVisible = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if session.framebufferImage != nil {
                RemoteCanvasView(session: session)
                    .ignoresSafeArea()
            } else {
                connectingState
            }

            RemoteKeyboardBridge(session: session, isActive: $keyboardIsVisible)
                .frame(width: 1, height: 1)
                .opacity(0.01)

            VStack {
                statusPill
                    .padding(.top, 8)
                Spacer()
                toolbar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    private var connectingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(AppTheme.tailBlue)
            Text(session.state.statusText)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(AppTheme.text)
        }
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(session.state == .connected ? AppTheme.connected : AppTheme.tailBlue)
                .frame(width: 7, height: 7)
            Text(session.state.statusText.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.2)
        }
        .foregroundStyle(AppTheme.text)
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay { Capsule().stroke(.white.opacity(0.14), lineWidth: 1) }
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            toolButton("Keyboard", systemImage: "keyboard", isActive: keyboardIsVisible) {
                keyboardIsVisible.toggle()
            }

            toolButton("Esc", systemImage: "escape") {
                session.pressKey(.escape)
            }

            toolButton("Tab", systemImage: "arrow.right.to.line") {
                session.pressKey(.tab)
            }

            toolButton("Right", systemImage: "cursorarrow.click.2") {
                session.click(.right)
            }

            toolButton("End", systemImage: "xmark", role: .destructive) {
                keyboardIsVisible = false
                session.disconnect()
            }
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }

    private func toolButton(
        _ title: String,
        systemImage: String,
        isActive: Bool = false,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(role == .destructive ? AppTheme.danger : (isActive ? AppTheme.tailBlue : AppTheme.text))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(isActive ? AppTheme.tailBlue.opacity(0.14) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

