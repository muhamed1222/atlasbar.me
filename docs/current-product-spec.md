# LimitBar Current Product Spec

Status: active source of truth
Last updated: 2026-04-07

## Purpose

LimitBar is a macOS menu bar utility for people who rotate between multiple AI coding accounts because of usage limits, cooldown periods, and subscription expiry.

The product should answer three questions quickly:

- which account is usable right now,
- which account will recover next,
- which subscription needs attention soon.

## Product Shape

- Platform: macOS 14+
- App type: menu bar utility
- Stack: SwiftUI, MenuBarExtra, Swift 6
- Runtime model: local-first, no backend
- Primary providers: Codex and Claude

## Current Data Model

### Codex

Codex data is sourced from:

- `~/.codex/auth.json`
- Codex/OpenAI usage endpoints
- local auth switching state for saved accounts

Accessibility scraping is not part of the active Codex implementation.

### Claude

Claude data is sourced from:

- connected Claude web session inside the app,
- session cookie when provided,
- local Claude token/session artifacts as fallback where available.

### Local State

The app stores locally:

- normalized usage snapshots,
- next reset timestamps,
- subscription expiry dates,
- per-account metadata such as priority and note,
- settings for polling, notifications, and language.

## Core User Experience

### Menu bar

The compact menu bar state should communicate:

- available capacity when an account is usable,
- low-capacity warning when only limited headroom remains,
- countdown when all known accounts are cooling down,
- stale/no-data state when the app has no reliable snapshot.

### Popover

The popover should show:

- last refresh state,
- all tracked accounts,
- per-account status, usage, and reset information,
- account switching for Codex where auth snapshots exist,
- account deletion,
- access to settings and quit.

### Settings

Settings should support:

- polling interval control for running vs closed Codex,
- Claude Web session connection,
- Claude cookie management,
- cooldown notifications,
- renewal reminder toggles,
- app language.

## Current Functional Scope

### Included

- multi-account tracking for Codex and Claude
- provider-aware account identity handling
- session and weekly usage display when available
- cooldown countdown and ready-state presentation
- cooldown-ready local notifications
- subscription renewal reminders
- local persistence of snapshots and account metadata
- saved Codex account switching
- Claude Web session flow through embedded `WKWebView`

### Not Included

- Accessibility-driven UI scraping as an active product path
- browser extensions
- hosted sync backend
- cross-device state sync
- Mac App Store sandbox compatibility
- signed consumer distribution workflow

## Architectural Constraints

- The app is `local-auth/session-first`.
- Provider adapters are preferred over provider-specific UI scraping.
- UI state stays local to the app runtime.
- Persistence format should remain stable unless migration is explicit.
- Errors should degrade to `stale`, `unknown`, or no-data states instead of crashing.

See:

- [Architecture ADR](adr/2026-04-07-local-auth-session-first-architecture.md)
- [Security and distribution notes](security-and-distribution.md)
- [Historical accessibility-oriented spec](../atlasbar_TZ.md)

## Privacy and Security Expectations

The app may access local auth/session artifacts required for tracking flows.

The app should not store or transmit:

- chat contents,
- project code,
- passwords,
- unrelated user data.

Sensitive local session material should stay on-device and only be used for the corresponding provider flow.

## Current Roadmap Priorities

### P1

- finish documentation alignment between code, spec, and setup docs
- make security and distribution constraints explicit
- keep reducing `AppModel` into thinner presentation/runtime seams

### P2

- improve popover UX polish and clarity for edge states
- harden Claude session flows and error messaging
- document realistic signing/distribution options

### P3

- evaluate future provider expansion only through explicit provider adapters
- consider optional fallback experiments separately from the main architecture

## Success Criteria

The current product is successful if a user can:

- open the menu bar app,
- see tracked Codex and Claude accounts,
- understand which account to use next,
- receive cooldown or renewal reminders,
- manage tracking setup without external infrastructure.
