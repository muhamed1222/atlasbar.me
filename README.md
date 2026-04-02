# LimitBar

macOS menu bar app for tracking Codex usage across accounts.

## What It Does

- reads the current Codex account from `~/.codex/auth.json`
- fetches usage data from the Codex/OpenAI usage endpoint
- uses the `auth.json + API` path only; no Accessibility or UsageParser fallback
- shows `Session` and `Weekly` remaining limits in the menu bar
- keeps local snapshots and basic account state

## Requirements

- macOS 14 or newer
- Xcode 16 or newer
- Codex app installed
- logged-in Codex account on the same Mac
- no Accessibility permission is required for the current data path

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

4. Open Codex and make sure you are logged in.

LimitBar expects Codex to have already created:

```bash
~/.codex/auth.json
```

Without that file, the app can launch, but account and usage data will not load.

## Notes

- `.gitignore` does not block running the app on another Mac. It only excludes local machine artifacts like `DerivedData`, `xcuserdata`, and profiling files.
- The repository does not include your local Codex auth file or tokens. That is intentional.
- Current development flow uses Xcode and `xcodegen`.

## Regenerate The Xcode Project

If the project file gets out of sync with the filesystem:

```bash
xcodegen generate
```

## Run Tests

```bash
xcodebuild test -project LimitBar.xcodeproj -scheme LimitBar -destination 'platform=macOS'
```

## Current Status

This is an early working version focused on:

- Codex account detection
- usage fetching
- compact menu bar UI
- local snapshot persistence

It is not yet packaged as a signed distributable `.app`.
