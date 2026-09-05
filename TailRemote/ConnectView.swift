import SwiftUI
import UniformTypeIdentifiers

struct ConnectView: View {
    @EnvironmentObject private var session: VNCSession
    @AppStorage("remoteHost") private var host = ""
    @AppStorage("remoteUsername") private var username = ""
    @AppStorage("rememberPassword") private var rememberPassword = true
    @StateObject private var credentials: ConnectionCredentials
    @StateObject private var savedMacs: SavedMacs
    @State private var showsMacEditor = false
    @State private var showsImporter = false
    @State private var draftHost = ""
    @State private var draftName = ""
    @State private var draftUsername = ""
    @State private var importError: String?

    private let port: UInt16 = 5900

    init(passwordStore: any RemotePasswordStoring = KeychainPasswordStore(), defaults: UserDefaults = .standard) {
        _credentials = StateObject(wrappedValue: ConnectionCredentials(store: passwordStore))
        _savedMacs = StateObject(wrappedValue: SavedMacs(defaults: defaults))
    }

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
        .onAppear(perform: prepareMacs)
        .onChange(of: credentialKey) { _, _ in loadPassword() }
        .onChange(of: username) { _, value in
            savedMacs.remember(hostname: host, username: value)
        }
        .sheet(isPresented: $showsMacEditor) { macEditor }
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                try savedMacs.importMacs(handle.read(upToCount: 1_048_577) ?? Data())
                importError = nil
                restoreSelection()
            } catch {
                importError = "Couldn’t import that list. Choose a TailRemote Mac export."
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
                macPicker

                fieldLabel("MAC USERNAME")
                TextField("Mac username", text: $username)
                    .accessibilityIdentifier("remote-username")
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .inputStyle()

                fieldLabel("PASSWORD")
                SecureField("Mac login password", text: $credentials.password)
                    .accessibilityIdentifier("remote-password")
                    .textContentType(.password)
                    .submitLabel(.go)
                    .inputStyle()
                    .onSubmit(connect)
            }

            if let importError {
                Text(importError)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.danger)
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Remember password", isOn: Binding(
                    get: { rememberPassword },
                    set: setRememberPassword
                ))
                .accessibilityIdentifier("remember-password")
                .tint(AppTheme.tailBlue)
                .font(.subheadline)
                Text("Stored securely on this iPhone after signing in. Turn off to forget it.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }

            if let error = credentials.errorMessage ?? session.credentialStorageError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
            .accessibilityIdentifier("connect-to-mac")
            .disabled(host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || credentials.password.isEmpty)
            .opacity(credentials.password.isEmpty ? 0.45 : 1)
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

    private var macPicker: some View {
        Menu {
            ForEach(savedMacs.macs) { mac in
                Button {
                    select(mac)
                } label: {
                    Label(mac.name, systemImage: savedMacs.matching(host)?.id == mac.id ? "checkmark" : "desktopcomputer")
                }
                .accessibilityIdentifier("saved-mac-\(mac.id)")
            }
            Divider()
            if !host.isEmpty {
                Button("Connection details", systemImage: "pencil") { editMac() }
            }
            Button("Add a Mac", systemImage: "plus") { editMac(isNew: true) }
            Button("Import Tailscale Macs", systemImage: "square.and.arrow.down") { showsImporter = true }
        } label: {
            HStack {
                Image(systemName: "desktopcomputer")
                    .foregroundStyle(AppTheme.tailBlue)
                Text(savedMacs.matching(host)?.name ?? "Choose a Mac")
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
            }
            .inputStyle()
        }
        .accessibilityIdentifier("mac-picker")
    }

    private var macEditor: some View {
        NavigationStack {
            Form {
                Section("Mac") {
                    TextField("Name", text: $draftName)
                    TextField("Tailscale name or IP address", text: $draftHost)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("mac-address")
                    TextField("Mac username", text: $draftUsername)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Text("In Tailscale, select your Mac and copy its address. Your username is the account you use to sign in to that Mac.")
                    Text("Import Tailscale Macs adds a saved device list exported from your Mac. It does not refresh automatically.")
                }
            }
            .navigationTitle("Mac details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showsMacEditor = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savedMacs.remember(hostname: draftHost, username: draftUsername, name: draftMac.name)
                        if let mac = savedMacs.matching(draftHost) { select(mac) }
                        showsMacEditor = false
                    }
                    .disabled(!SavedMacs.isValid(draftMac))
                }
            }
        }
    }

    private var draftMac: SavedMac {
        SavedMac(hostname: draftHost, name: draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? draftHost : draftName,
                 username: draftUsername)
    }

    private func editMac(isNew: Bool = false) {
        draftHost = isNew ? "" : host
        draftName = isNew ? "" : savedMacs.matching(host)?.name ?? host
        draftUsername = isNew ? "" : username
        showsMacEditor = true
    }

    private func select(_ mac: SavedMac) {
        credentials.password = ""
        // Keep a previously used alias as the credential key when selecting it.
        if !mac.addresses.contains(SavedMac.normalize(host)) { host = mac.hostname }
        username = mac.username
        loadPassword()
    }

    private func prepareMacs() {
        savedMacs.remember(hostname: host, username: username)
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                try savedMacs.importPendingFile(at: documents.appendingPathComponent("TailscaleMacs.json"))
            } catch {
                importError = "Couldn’t import the Mac list. You can try importing it again."
            }
        }
        restoreSelection()
    }

    private func restoreSelection() {
        if let current = savedMacs.matching(host) {
            select(current)
        } else if host.isEmpty, let first = savedMacs.macs.first {
            select(first)
        } else {
            loadPassword()
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
        savedMacs.remember(hostname: host, username: username)
        session.connect(
            hostname: host.trimmingCharacters(in: .whitespacesAndNewlines),
            port: port,
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: credentials.password,
            rememberPassword: rememberPassword
        )
    }

    private var credentialKey: RemoteCredentialKey {
        RemoteCredentialKey(hostname: host, port: port, username: username)
    }

    private func loadPassword() {
        credentials.load(for: credentialKey, rememberPassword: rememberPassword)
    }

    private func setRememberPassword(_ enabled: Bool) {
        if !enabled {
            guard credentials.forget(for: credentialKey) else { return }
        }
        rememberPassword = enabled
        if enabled && credentials.password.isEmpty {
            loadPassword()
        }
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
