# LimitBar Provider Refactor Design

## Goal

Reduce coupling in `AppModel` and make the runtime data path explicit:

- primary path: Codex `auth.json` + usage API
- no Accessibility/parser fallback in the current architecture
- UI state stays in `AppModel`

## Design

Introduce a provider layer that returns a normalized usage payload:

- `CurrentUsageProvider` protocol
- `APIBasedUsageProvider` for `auth.json` + usage endpoint
- `CodexAuthReader` for account discovery
- `CodexUsageClient` for API requests
- `UsageStateCoordinator` for polling and normalization

`AppModel` should depend on protocol seams instead of concrete auth/API code.

## Scope

- keep current UI behavior
- keep persistence format stable
- keep notifications behavior stable
- fix polling coordinator usage and remove the current extra instantiation/warning
- add tests for auth lookup and API-backed usage loading

## Non-goals

- no redesign of menu bar UI
- no full multi-account architecture
- no Mac App Store sandbox work
- no Accessibility or UsageParser fallback path
