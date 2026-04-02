# LimitBar V2 Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the V2 foundation for LimitBar by separating provider-owned account data from local metadata and settings, while keeping the current Codex refresh loop stable.

**Architecture:** Extend persisted state with dedicated V2 domain types instead of overloading `Account`. Keep the runtime flow in `AppModel` for now, but route user-configurable polling and notification preferences through a new settings coordinator so later Settings UI and renewal scheduling can plug into stable boundaries.

**Tech Stack:** Swift, SwiftUI, Foundation Codable JSON persistence, UserNotifications, Swift Testing, Xcode

---

## Planned File Structure

- `LimitBar/Domain/Account.swift`
  Provider-owned account identity only.
- `LimitBar/Domain/AccountPriority.swift`
  Local priority enum plus sorting weight helpers.
- `LimitBar/Domain/AccountMetadata.swift`
  User-owned per-account metadata.
- `LimitBar/Domain/AppSettingsState.swift`
  App-level persisted settings and renewal reminder toggles.
- `LimitBar/Domain/SubscriptionDerivedState.swift`
  Runtime-derived subscription state and formatting helpers.
- `LimitBar/Domain/UsageSnapshot.swift`
  Removes persisted subscription source-of-truth duplication by deriving state from expiry.
- `LimitBar/App/SettingsCoordinator.swift`
  Reads/writes app settings and polling values from persisted state.
- `LimitBar/App/AppModel.swift`
  Holds settings + metadata, merges them into sorted UI state, keeps refresh path stable.
- `LimitBar/Services/SnapshotStore.swift`
  Backward-compatible load/save for V2 persisted state.
- `LimitBar/UI/AccountRowView.swift`
  Displays priority badge, note preview, and subscription state.
- `LimitBar/UI/MenuBarRootView.swift`
  Uses sorted account presentation from the model.
- `LimitBarTests/SnapshotStoreTests.swift`
  Migration/defaults coverage.
- `LimitBarTests/AppModelTests.swift`
  Sorting and metadata preservation coverage.
- `LimitBarTests/SettingsCoordinatorTests.swift`
  Settings defaults and update coverage.

## Scope Guardrails

- This plan does not add the Settings window yet.
- This plan does not add renewal scheduling yet.
- This plan keeps `Codex only` runtime behavior.
- This plan keeps the current notification manager for cooldown notifications.
