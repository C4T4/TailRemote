import SwiftUI

struct ConnectView: View {
    @EnvironmentObject private var session: VNCSession
    @AppStorage("remoteHost") private var host = ""
    @AppStorage("remoteUsername") private var username = ""
    @State private var password = ""

    private let port: UInt16 = 5900

    var body: some View {
        ZStack {
            AppTheme.ink.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    connectionCard
                    controlsHint
                }
                .frame(maxWidth: 540)
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            TailSignalMark()

            Text("Your Mac,\nwithin reach.")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .tracking(-1.4)
                .foregroundStyle(AppTheme.text)

            Text("A direct Screen Sharing connection inside your private tailnet.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppTheme.muted)
        }
    }

    private var connectionCard: some View {
        VStack(spacing: 18) {
            HStack {
                Label("PRIVATE TAILNET", systemImage: "lock.fill")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.connected)
                Spacer()
                Text(":5900")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(AppTheme.muted)
            }

            VStack(spacing: 12) {
                fieldLabel("MAC")
                TextField("Mac hostname", text: $host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .inputStyle()

                fieldLabel("USER")
                TextField("Mac username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .inputStyle()

                fieldLabel("PASSWORD")
                SecureField("Mac login password", text: $password)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .inputStyle()
                    .onSubmit(connect)
            }

            if let error = session.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: connect) {
                HStack {
                    Text("Connect to Mac")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(height: 54)
                .background(AppTheme.tailBlue)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
            .opacity(password.isEmpty ? 0.45 : 1)
        }
        .padding(20)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        }
    }

    private var controlsHint: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.draw.fill")
                .foregroundStyle(AppTheme.tailBlue)
            Text("Hold, then drag to move sliders or windows.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(AppTheme.muted)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(1.4)
            .foregroundStyle(AppTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func connect() {
        session.connect(
            hostname: host.trimmingCharacters(in: .whitespacesAndNewlines),
            port: port,
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
    }
}

private struct TailSignalMark: View {
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { column in
                VStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { row in
                        Circle()
                            .fill(column == 2 && row == 0 ? AppTheme.connected : AppTheme.tailBlue.opacity(0.32 + Double(column + row) * 0.08))
                            .frame(width: 7, height: 7)
                    }
                }
            }
        }
        .padding(12)
        .background(AppTheme.panelRaised)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel("TailRemote")
    }
}

private extension View {
    func inputStyle() -> some View {
        self
            .foregroundStyle(AppTheme.text)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(AppTheme.ink.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.07), lineWidth: 1)
            }
    }
}
