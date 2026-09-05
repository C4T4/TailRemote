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

The host, username, and Remember password preference are stored in iOS `UserDefaults`.
When Remember password is enabled, the password is saved only after successful
authentication, using a generic password item in the app's Keychain. Each item is
scoped to the normalized hostname, port, and username. Changing the selected Mac
or account clears the form password before loading a matching saved item.

Items use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and disable synchronization.
They are accessible only while the iPhone is unlocked, do not sync to iCloud, and
do not migrate to another device. Turning Remember password off removes the item
for the selected Mac/account. Failed sign-ins do not overwrite a saved password.

Passwords are never stored in `UserDefaults`, logs, analytics, or the repository.
The active session's in-memory password is cleared on disconnect. Keychain errors
are shown without including the password, account, or host in diagnostics.
