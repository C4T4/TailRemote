# TestFlight and App Store prep (Waack LLC)

Bundle ID: `com.waack.TailRemote`  
Version: `1.0.0` (build `1`)  
Team: Waack LLC (paid Apple Developer)

## Already done in this repo

- Bundle IDs switched from `com.example.*` to `com.waack.*`
- Marketing version `1.0.0` and build `1`
- Export compliance Info.plist key set to non-exempt encryption = NO (standard exempt networking / Screen Sharing). Confirm the App Store Connect questionnaire matches.
- Local network usage string present
- Single 1024×1024 App Store icon in the asset catalog
- Privacy policy draft in [`PRIVACY.md`](PRIVACY.md)

## You still do in Apple portals + Xcode

### 1. Apple Developer (developer.apple.com)

1. Sign in as Waack LLC.
2. Certificates, Identifiers & Profiles → Identifiers → register App ID `com.waack.TailRemote`.
3. Enable only capabilities you actually use (none required beyond the defaults for this app today).

### 2. App Store Connect

1. My Apps → New App → iOS → name TailRemote → Bundle ID `com.waack.TailRemote`.
2. SKU e.g. `tailremote-ios`.
3. Host [`PRIVACY.md`](PRIVACY.md) as a public HTTPS page and paste that URL into App Privacy / Privacy Policy URL.
4. App Privacy answers (honest baseline for current code):
   - No data collected by the developer from the app for tracking or analytics
   - Data that may stay on device only: credentials (Keychain), product interaction / identifiers you choose to disclose if ASC forces a category for on-device Mac list storage — TailRemote does not upload that list to Waack LLC
5. Prepare screenshots (6.7" and 6.1" iPhone at minimum for submission).
6. Review notes for Apple: explain Tailscale + Screen Sharing, that there is no demo account, and that reviewers need Tailscale on a Mac with Screen Sharing enabled (or offer a short loom / setup steps).

### 3. Xcode on this Mac

1. Open `TailRemote.xcodeproj`.
2. Signing & Capabilities → Team → **Waack LLC** (not Personal Team).
3. Confirm Bundle Identifier is `com.waack.TailRemote`.
4. Product → Archive (generic iOS device / Any iOS Device).
5. Distribute App → App Store Connect → Upload.
6. In App Store Connect → TestFlight, wait for processing, add internal testers, then external if needed (Beta App Review for external).

### 4. Privacy policy URL

Public privacy policy URL (GitHub Pages):

`https://c4t4.github.io/TailRemote/privacy/`

Source markdown remains in [`PRIVACY.md`](PRIVACY.md). Keep the HTML under `docs/privacy/` in sync when the policy changes.

## Regenerating the Xcode project

After editing `project.yml`:

```sh
cd /path/to/TailRemote
xcodegen generate
```

Commit both `project.yml` and the updated `TailRemote.xcodeproj`.
