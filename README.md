<p align="center">
  <img src="Assets/Brand/tailremote-logo.png" width="112" alt="TailRemote logo">
</p>

<h1 align="center">TailRemote</h1>

<p align="center">
  A direct, private iPhone remote for your Mac.
</p>

<p align="center">
  <img src="Assets/Brand/tailremote-hero.png" alt="TailRemote connecting an iPhone to a Mac">
</p>

TailRemote is a small, open-source iPhone client for controlling a Mac through macOS Screen Sharing over Tailscale. It connects directly to the Mac: there is no relay, hosted service, account system, or companion app.

> TailRemote is an early MVP intended for personal use on a trusted tailnet.

## Features

- Apple Screen Sharing authentication through RoyalVNCKit
- Live remote framebuffer with a local pointer
- Relative touchpad-style pointer control, clicks, dragging, and scrolling
- Pinch zoom from 1× to 4× with manual panning and cursor edge-following
- iOS keyboard input plus Escape, Tab, and right-click shortcuts
- Remembered host and username; the password stays in memory only for the active connection

## Quick start

You need a Mac, an iPhone with iOS 17+, Xcode, and [Tailscale](https://tailscale.com/download) on both devices.

1. On your Mac, open **System Settings → General → Sharing** and enable **Screen Sharing**.
2. Clone and open TailRemote:

   ```sh
   git clone https://github.com/C4T4/TailRemote.git
   open TailRemote/TailRemote.xcodeproj
   ```

3. Connect your iPhone. In **Signing & Capabilities**, choose your Personal Team and set a unique bundle ID.
4. Select your iPhone in Xcode and press **Run**.
5. Enter your Mac's Tailscale name, macOS username, and login password.

## Problems?

- Signing error: choose your Personal Team and change the bundle ID.
- Cannot connect: check Tailscale and Screen Sharing.
- Login fails: run `whoami` on your Mac and use that username.

## Controls

| Gesture | Action |
| --- | --- |
| One-finger drag | Move the pointer |
| Tap / double-tap | Click / double-click |
| Hold, then drag | Drag a window, slider, or item |
| Two-finger tap | Right-click |
| Two-finger drag at 1× | Scroll the Mac |
| Pinch | Zoom from 1× to 4× |
| Two-finger drag while zoomed | Pan around the desktop |

While zoomed, moving the pointer near an edge automatically follows it around the desktop.

## Security model

- Tailscale provides private network reachability; it does not replace Screen Sharing authentication.
- TailRemote sends credentials only to the selected Screen Sharing server during the authentication handshake.
- The host and username are stored in iOS `UserDefaults` for convenience.
- The password is never written to disk or committed to the repository. It is cleared when the session disconnects.
- TailRemote does not open ports, operate a relay, collect analytics, or send telemetry.

Only connect to Macs and networks you trust. See [SECURITY.md](SECURITY.md) for reporting vulnerabilities and the supported threat model.

## Development

The generated Xcode project is committed so contributors can build immediately. [`project.yml`](project.yml) is its source of truth.

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project TailRemote.xcodeproj \
  -scheme TailRemote \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  test
```

RoyalVNCKit is pinned to a tested revision in `project.yml` and `Package.resolved`. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for dependency licenses.

## Known limitations

- One saved Mac profile
- No remote user discovery; Screen Sharing does not expose account names before authentication
- No audio, file transfer, or App Store distribution
- Keyboard support focuses on text entry and a small set of special keys

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Please keep the app direct, private, and deliberately small.

## License

TailRemote is available under the [MIT License](LICENSE).

TailRemote is not affiliated with or endorsed by Tailscale Inc. or Apple Inc. Tailscale and Apple product names are trademarks of their respective owners.
