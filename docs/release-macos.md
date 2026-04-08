# LimitBar macOS Release Flow

Status: active  
Last updated: 2026-04-08

## Goal

This document defines the direct-distribution release flow for a signed and notarized macOS build of LimitBar.

## Free Local-Only Flow

If you only need LimitBar on your own Mac, you do not need `Developer ID` or notarization.

Use:

```bash
./scripts/local-release-macos.sh
```

This builds a `Release` app, installs it locally, and launches it. To remove it later:

```bash
./scripts/uninstall-local-macos.sh
```

This is the recommended free path for personal use on the same machine.

## Required prerequisites

You need:

- Xcode 16 or newer
- a valid `Developer ID Application` certificate in the local keychain
- optionally a `Developer ID Installer` certificate if you later decide to ship `.pkg`
- Apple notarization credentials stored via `xcrun notarytool store-credentials`

## Check signing identities

```bash
./scripts/check-release-signing-macos.sh
```

Or inspect raw identities manually:

```bash
security find-identity -v -p codesigning
```

You should see a valid `Developer ID Application` identity before attempting export.

The preflight script also checks whether a `notarytool` keychain profile is already configured. By default it looks for `limitbar-notary`, or you can pass a custom profile name:

```bash
./scripts/check-release-signing-macos.sh my-notary-profile
```

## Archive

```bash
./scripts/archive-release-macos.sh
```

Default output:

- `build/archive/LimitBar.xcarchive`

## Export Developer ID app

```bash
./scripts/export-developer-id-macos.sh
```

This exports a signed `.app` for direct distribution and validates it with:

- `codesign --verify --deep --strict`
- `spctl --assess --type execute --verbose=4`

Default output:

- `build/export/developer-id/LimitBar.app`

Optional environment variables:

- `DEVELOPMENT_TEAM`
- `SIGNING_CERTIFICATE`
- `ARCHIVE_PATH`
- `EXPORT_PATH`

## Notarize and staple

Store notarization credentials once:

```bash
xcrun notarytool store-credentials limitbar-notary
```

This will prompt for your Apple credentials and save them in the login keychain under the chosen profile name.

Then run:

```bash
NOTARYTOOL_PROFILE=limitbar-notary ./scripts/notarize-macos.sh
```

Default output:

- notarized archive zip: `build/export/LimitBar-macOS.zip`
- stapled app: `build/export/developer-id/LimitBar.app`

## End-to-end release

```bash
NOTARYTOOL_PROFILE=limitbar-notary ./scripts/release-developer-id-macos.sh
```

This executes:

1. archive
2. Developer ID export
3. notarization
4. stapling

## Current machine status

If export fails with a message about a missing `Developer ID Application` identity, the machine is not yet ready for signed direct distribution. Install the certificate first, then rerun the flow.
