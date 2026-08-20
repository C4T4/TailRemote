# Security policy

## Supported versions

TailRemote is an early-stage project. Security fixes are made on the latest `main` branch only.

## Reporting a vulnerability

Do not open a public issue for a vulnerability involving credentials, authentication, network access, or remote input.

Use GitHub's **Security → Report a vulnerability** flow. If private vulnerability reporting is unavailable, contact the maintainer privately through the GitHub profile rather than publishing exploit details.

Include the affected commit, iOS and macOS versions, connection method, reproduction steps, and the security impact. Do not include real passwords, private keys, authentication tokens, Tailscale IP addresses, or tailnet hostnames.

## Threat model

TailRemote assumes:

- The iPhone and Mac are trusted devices.
- Tailscale or another trusted network limits who can reach Screen Sharing.
- macOS Screen Sharing authentication remains enabled.
- The Mac account password is not reused or shared with untrusted people.

TailRemote does not make an exposed VNC server safe. Do not forward TCP port `5900` from the public internet.

## Credential handling

The host and username are stored in iOS `UserDefaults`. The password is held in process memory for the active connection and cleared on disconnect. It is not stored in `UserDefaults`, Keychain, logs, analytics, or the repository.
