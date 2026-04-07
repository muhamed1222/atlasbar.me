# ADR: Local Auth / Session First Architecture

- Status: accepted
- Date: 2026-04-07

## Context

The original product spec in [atlasbar_TZ.md](/Users/kelemetovmuhamed/Documents/atlasbar.me/atlasbar_TZ.md) describes LimitBar as an Accessibility-driven, read-only companion for the Codex desktop app. That document assumes the application:

- finds the Codex window,
- reads usage data from the UI through Accessibility,
- avoids browser or session dependencies,
- and does not rely on local auth artifacts.

The implemented product has evolved differently.

Current production data paths are:

- Codex account detection and usage from `~/.codex/auth.json` plus the Codex/OpenAI usage endpoint
- Claude usage from a connected Claude web session when available
- Claude fallback data from local Claude token/session artifacts
- local snapshot persistence for UI state, cooldown tracking, metadata, and notifications

This approach is already reflected in the shipping code and README, but it was not captured in a single architecture decision record.

## Decision

LimitBar will use a `local-auth/session-first` architecture.

That means:

- Codex is sourced from local auth state and provider APIs, not from Accessibility scraping.
- Claude is sourced from a local Claude web session or cookie-backed session flow, with local fallback readers where possible.
- The menu bar app remains local-first and does not require a backend service.
- Accessibility-based extraction is not part of the active architecture and should be treated as historical exploration unless explicitly reintroduced by a future ADR.

## Why

### 1. Stability

`auth.json`, structured provider responses, and cached local artifacts are more stable than desktop UI tree scraping. Accessibility extraction is highly sensitive to app layout, text changes, localization, and view hierarchy churn.

### 2. Precision

Provider-backed usage data gives stronger semantics than inferred UI text. This is especially important for:

- session percentage,
- weekly percentage,
- reset timestamps,
- subscription expiry,
- and stale-vs-live state reconciliation.

### 3. Multi-provider fit

A provider-agnostic architecture is easier to implement when each provider has its own local/source adapter boundary. Accessibility was Codex-specific by construction, while the current approach scales better to Claude and future providers.

### 4. Local-first product shape

The app does not need a hosted backend to deliver value. Local persistence plus provider/session readers are enough for:

- menu bar presentation,
- account switching,
- cooldown notifications,
- renewal reminders,
- and per-account metadata.

## Consequences

### Positive

- clearer provider boundaries,
- better testability,
- lower coupling to desktop UI structure,
- more deterministic refresh behavior,
- easier evolution toward additional providers.

### Negative

- the app depends on local auth/session artifacts being present on the machine,
- Claude web tracking introduces `WKWebView` and cookie/session management complexity,
- sandboxing is harder because the app needs access to local files, keychain-backed credentials, and session state,
- distribution and trust requirements must be documented more explicitly.

## Security and Privacy Implications

The active architecture changes the trust boundary compared with the original spec.

LimitBar may locally access:

- `~/.codex/auth.json`
- Claude session/cookie state
- local Claude token/session artifacts
- persisted local snapshots and account metadata

LimitBar should continue to avoid storing or transmitting:

- chat content,
- project code,
- passwords,
- raw secret material beyond what is required for local machine operation.

The app should remain explicit that session cookies and auth-derived state are used only for local tracking flows.

## Implementation Notes

This decision matches the current codebase structure:

- Codex readers/providers:
  - [CodexAuthReader.swift](/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/Services/CodexAuthReader.swift)
  - [CodexUsageAPI.swift](/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/Services/CodexUsageAPI.swift)
  - [CodexAccessTokenProvider.swift](/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/Services/CodexAccessTokenProvider.swift)
- Claude readers/providers:
  - [ClaudeUsagePipeline.swift](/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/Services/ClaudeUsagePipeline.swift)
  - [ClaudeWebSessionController.swift](/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/Services/ClaudeWebSessionController.swift)
  - [ClaudeSessionRuntime.swift](/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/App/ClaudeSessionRuntime.swift)
- Local state/orchestration:
  - [SnapshotStore.swift](/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/Services/SnapshotStore.swift)
  - [RefreshEngine.swift](/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/App/RefreshEngine.swift)
  - [AppStartupRuntime.swift](/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/App/AppStartupRuntime.swift)
  - [AppStateSideEffectsRuntime.swift](/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/App/AppStateSideEffectsRuntime.swift)

## Rejected Alternative

### Accessibility-first architecture

Rejected as the active implementation model because it is less stable, less testable, more provider-specific, and weaker as a long-term base for a multi-provider menu bar utility.

This does not forbid future experiments with Accessibility as a fallback path, but that would need a separate ADR with explicit scope, trust model, and failure semantics.
