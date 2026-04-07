# LimitBar Security And Distribution Notes

Status: active
Last updated: 2026-04-07

## Purpose

This document defines the current trust boundary, local data access model, sandbox constraints, and realistic distribution path for LimitBar.

It complements:

- [Current product spec](current-product-spec.md)
- [Local auth/session architecture ADR](adr/2026-04-07-local-auth-session-first-architecture.md)

## Trust Boundary

LimitBar is a local-first macOS utility. It runs entirely on the user's machine and does not depend on a hosted backend.

The app may read local provider artifacts required for usage tracking and account state reconciliation.

### Allowed local access

- Codex auth state from `~/.codex/auth.json`
- provider-backed usage responses derived from the active local auth/session state
- Claude web session state through the embedded app flow
- Claude session cookie when explicitly provided by the user
- local Claude token/session artifacts used for fallback usage reconstruction
- local snapshot persistence and per-account metadata written by LimitBar itself

### Explicit non-goals

The app should not read, store, or transmit:

- chat content
- source code from user projects
- passwords
- Gmail or arbitrary mailbox contents
- unrelated browser data
- general desktop text scraping as a default mechanism

## Local Storage Model

### Codex auth

Codex usage depends on the local `auth.json` created by Codex.

This means:

- tracking only works when the local machine already has a valid Codex login
- missing or stale auth state should degrade to unavailable tracking rather than causing crashes
- the app should treat auth-derived data as sensitive local machine state

### Claude cookie and session state

Claude tracking may use:

- an embedded Claude web session inside the app
- a session cookie explicitly entered by the user
- local Claude fallback sources when web session data is unavailable

Session cookie material should be treated as sensitive.

### LimitBar persistence

LimitBar stores local state for:

- normalized snapshots
- reset timestamps
- subscription expiry timestamps
- account priority and notes
- settings such as polling, reminders, and language

This data is product state, not provider auth state.

## Secrets Handling

The current expectation is:

- provider auth/session material stays on-device
- only the minimum required auth/session data is used for provider-specific flows
- persistent storage of session-sensitive values should prefer platform-secure storage when supported

In practical terms:

- Claude cookie material belongs in macOS Keychain-backed storage
- snapshot and metadata persistence belongs in the app's local persisted state
- raw provider auth artifacts owned by another app, such as Codex `auth.json`, should not be duplicated unless the feature explicitly requires a user-managed snapshot flow

## Sandbox Constraints

The current architecture is not aligned with a strict Mac App Store sandbox posture.

Why:

- Codex tracking depends on reading `~/.codex/auth.json`
- Claude tracking depends on local session/cookie and `WKWebView` session flows
- the app benefits from direct local file and keychain-adjacent access patterns that are awkward or unavailable under a locked-down App Store distribution model

Because of that:

- Mac App Store sandbox compatibility is not a current goal
- distribution assumptions should be based on direct distribution, not App Store distribution
- any future sandbox-compatible variant would likely need a narrower feature set or a different provider integration model

## User Trust Expectations

The product should be explicit about:

- which local files or session sources it depends on
- what it stores itself
- what it never reads
- why direct local access is required for the current feature set

This matters because the app operates close to auth/session material even though it is not a credential manager.

## Realistic Distribution Path

The realistic near-term release path is:

1. direct distribution outside the Mac App Store
2. Developer ID signing
3. Apple notarization
4. clear setup documentation explaining local auth/session prerequisites

This gives a viable path to a signed downloadable app without forcing the architecture into App Store sandbox constraints prematurely.

## Not Recommended Right Now

The following path is not recommended as the primary release target:

- Mac App Store distribution with full current feature parity

That path creates pressure to redesign tracking boundaries before the product has stabilized.

## Release Checklist Direction

Before shipping a broader external build, the project should document:

- what local sources are accessed
- where cookies or session values are stored
- what telemetry, if any, leaves the machine
- what failure mode users should expect when auth/session artifacts are missing
- whether the build is signed and notarized

## Practical Product Positioning

LimitBar should be described as:

- a local menu bar utility
- provider/session-aware
- on-device by default
- dependent on existing local provider login state

It should not be described as:

- a generic desktop scraper
- an App Store sandboxed utility
- a cloud-synced account management platform
