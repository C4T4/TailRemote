# Privacy Policy for TailRemote

**Effective date:** 6 September 2026  
**Developer:** Waack LLC  
**App:** TailRemote (`com.waack.TailRemote`)

## Summary

TailRemote is a private iPhone remote for your Mac. It connects over your Tailscale network to macOS Screen Sharing. There is no TailRemote account, no TailRemote cloud backend, and no analytics or advertising SDK in the app.

## Data TailRemote handles on your device

| Data | Where it lives | Purpose |
| --- | --- | --- |
| Mac display name, Tailscale address/hostname, port, username | On-device (`UserDefaults`) | Remember Macs you added or imported |
| Screen Sharing password (optional) | On-device Keychain when **Remember password** is on | Sign in again without retyping |
| Live screen pixels and input events | In memory during an active session only | Show and control the remote Mac |

Passwords are never written to `UserDefaults`, logs, or the repository. Keychain items stay on that iPhone, do not sync to iCloud, and are not available while the device is locked. Turning **Remember password** off deletes the saved password for that Mac and username. Disconnect clears the in-memory session password.

## What TailRemote does not collect

TailRemote does not:

- create user accounts or require an email login for the app itself
- operate a relay, hosted desktop service, or TailRemote server that receives your screen
- include analytics, crash reporters, advertising, or tracking SDKs
- sell personal data or share it with data brokers

## Network destinations

When you connect, TailRemote talks only to the Mac you select (Screen Sharing over your private Tailscale network). Credentials are sent to that Mac during the Screen Sharing authentication handshake.

Importing Macs from Tailscale uses a JSON file you export locally on your Mac. That file is not uploaded to Waack LLC.

Tailscale itself is a separate product from Tailscale Inc. Its privacy practices are governed by Tailscale, not by this policy.

## Third-party components

TailRemote embeds RoyalVNCKit for Screen Sharing / VNC client functionality. See the app’s third-party notices for licenses. Those components run on your device as part of the connection you start.

## Children

TailRemote is not directed at children under 13.

## Your choices

- Do not enable **Remember password** if you do not want credentials stored on the iPhone.
- Delete saved Macs and passwords from within the app, or delete the app to remove on-device data.
- Only connect to Macs and networks you trust.

## Changes

We may update this policy when the app’s data practices change. The effective date at the top will be revised when that happens.

## Contact

Questions about this policy or TailRemote privacy: **hello@catalinwaack.com** (Waack LLC).
