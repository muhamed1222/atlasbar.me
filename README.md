# LimitBar

macOS menu bar app for tracking Codex and Claude usage across accounts.

## What It Does

- tracks Codex accounts from `~/.codex/auth.json` and the Codex/OpenAI usage endpoint
- tracks Claude accounts from a connected Claude web session when available, or from Claude local token logs as a fallback
- stores local snapshots, per-account metadata, and cooldown timing
- shows session and weekly limits in the menu bar and popover
- supports switching between saved Codex accounts from the menu
- schedules cooldown-ready and subscription renewal notifications

## Requirements

- macOS 14 or newer
- Xcode 16 or newer
- Codex app installed for Codex account tracking and account switching
- a logged-in Codex account on the same Mac if you want Codex usage
- Claude Code or a Claude web session if you want Claude usage
- no Accessibility permission is required for the current data paths

## Architecture Notes

- The current product spec is in `docs/current-product-spec.md`.
- Current implementation is `local-auth/session-first`, not Accessibility-first.
- The architecture decision record is in `docs/adr/2026-04-07-local-auth-session-first-architecture.md`.
- Security, trust boundary, and release constraints are documented in `docs/security-and-distribution.md`.
- The original Accessibility-oriented product spec is kept for historical context in `atlasbar_TZ.md`.

## Run On Another Mac

1. Clone the repository:

```bash
git clone https://github.com/muhamed1222/atlasbar.me.git
cd atlasbar.me
```

2. Open the project in Xcode:

```bash
open LimitBar.xcodeproj
```

3. In Xcode, select the `LimitBar` scheme and press `Run`.

4. Open Codex and make sure you are logged in if you want Codex data.

LimitBar expects Codex to have already created:

```bash
~/.codex/auth.json
```

Without that file, the app can still launch, but Codex account and usage data will not load.

If you also want Claude percentages:

- connect Claude Web inside `Settings -> General -> Claude quota`, or
- provide a Claude session cookie, or
- let LimitBar fall back to local Claude token logs when available

## Notes

- `.gitignore` does not block running the app on another Mac. It only excludes local machine artifacts like `DerivedData`, `xcuserdata`, and profiling files.
- The repository does not include your local Codex auth file, Claude session cookie, or tokens. That is intentional.
- Current development flow uses Xcode and `xcodegen`.

## Regenerate The Xcode Project

If the project file gets out of sync with the filesystem:

```bash
xcodegen generate
```

## Run Tests

```bash
xcodebuild test -project LimitBar.xcodeproj -scheme LimitBar -destination 'platform=macOS,arch=arm64'
```

## Build Release

```bash
./scripts/build-release-macos.sh
```

## Local Release For This Mac

```bash
./scripts/local-release-macos.sh
```

This is the main free local-only flow. It builds the app in `Release`, installs it into `/Applications` when writable or `~/Applications` otherwise, and launches it.

## Install Release Locally

```bash
./scripts/install-release-macos.sh
```

## Package Local Download Zip

```bash
./scripts/package-local-zip-macos.sh
```

This builds the app in `Release` and creates a stable archive at `build/export/local-download/LimitBar-macOS.zip`. Upload that file to GitHub Releases with the same asset name so the promo site download button keeps working.

## Uninstall Local Release

```bash
./scripts/uninstall-local-macos.sh
```

## Archive For Distribution

```bash
./scripts/archive-release-macos.sh
```

## Check Signing And Notarization Readiness

```bash
./scripts/check-release-signing-macos.sh
```

## Export Developer ID Build

```bash
./scripts/export-developer-id-macos.sh
```

## Notarize Build

```bash
NOTARYTOOL_PROFILE=limitbar-notary ./scripts/notarize-macos.sh
```

## Signed Release Docs

- Direct distribution and notarization flow: `docs/release-macos.md`

## Current Status

This is an early working version focused on:

- Codex + Claude account detection
- usage fetching and cooldown tracking
- compact menu bar UI
- local snapshot persistence and account switching

It can be built and installed locally as a Release `.app` with the free local-only flow, but it is not yet packaged as a notarized distributable build.
