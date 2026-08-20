# Contributing to TailRemote

TailRemote is intentionally a small, direct iPhone-to-Mac remote-control client. Contributions should preserve its core constraints: no hosted backend, no relay, no analytics, and no credential persistence.

## Before opening a pull request

1. Open an issue before starting a large feature or architectural change.
2. Keep each pull request focused on one problem.
3. Add or update tests for geometry, input, and connection-state changes.
4. Never commit hostnames, IP addresses, usernames, passwords, signing teams, provisioning profiles, or certificates.
5. Run the simulator test suite and describe the physical-device testing you performed.

## Development setup

1. Install Xcode 16 or newer.
2. Install XcodeGen with `brew install xcodegen`.
3. Run `xcodegen generate` after changing `project.yml`.
4. Open `TailRemote.xcodeproj` and build the `TailRemote` scheme.

The generated Xcode project is tracked. Include it in the same change whenever `project.yml` modifies the project structure or build settings.

## Test command

```sh
xcodebuild -project TailRemote.xcodeproj \
  -scheme TailRemote \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  test
```

If that simulator is unavailable, substitute an installed iPhone simulator from `xcrun simctl list devices available`.

## Code style

- Prefer native SwiftUI and UIKit APIs over additional dependencies.
- Keep authentication and networking failures explicit and user-actionable.
- Keep touch interactions predictable and test their coordinate math separately.
- Do not weaken macOS Screen Sharing authentication or suggest exposing port `5900` publicly.
