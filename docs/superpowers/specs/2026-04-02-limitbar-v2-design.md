# LimitBar V2 Design

## Goal

Build the first V2 slice for LimitBar on top of the current Codex-only MVP:

- automatic subscription status tracking from `auth.json` / API data;
- renewal reminder notifications at `7d / 3d / 1d / same day`;
- account priorities with list sorting;
- one free-form note per account;
- a real Settings window with sidebar sections.

V2 remains `Codex-only`, but the data model and state boundaries must be ready for future provider expansion such as Claude in V3.

## Product Decisions

- Provider scope for V2: `Codex only`
- Future-proofing: data model and interfaces should allow adding more providers later without rewriting the current V2 structures
- Subscription expiry source: `automatic only`
- Account priority behavior: `label + sorting`
- Renewal reminder configuration: `7d / 3d / 1d / same day`, each individually enabled/disabled in Settings
- Account notes: `one free-form text note`
- Settings UX: separate window with sidebar sections

## Reference Inputs

### Current repo patterns to keep

- `AppModel -> UsageStateCoordinator -> SnapshotStore -> UI`
- simple JSON persistence instead of database infrastructure
- normalized usage payload flow through `CurrentUsagePayload`

### Local repo references

- `../jobus/jobus-back/src/routes/notifications-state.ts`
  Use the idea of keeping notification state logic separate from the UI and from the domain entities that trigger it.
- `../jobus/jobus-front/components/subscriptions/profile-subscriptions-card.tsx`
  Use the idea of a dedicated management surface for subscription-related data rather than cramming controls into a compact primary UI.
- `../artistocrat.space/src/app/(dashboard)/settings/page.tsx`
  Use the idea of a dedicated settings area for grouped controls.
- `../artistocrat.space/src/app/(dashboard)/settings/telegram-link-card.tsx`
  Use the idea of explicit `expiresAt`-driven display states.

### External reference

- [SpotMenu](https://github.com/kmikiy/SpotMenu)
  Use the preferences-window pattern for a macOS menu bar app instead of forcing all configuration into the dropdown.

## Recommended Architecture

Implement V2 as a light domain-first extension of the current MVP:

1. Keep the current runtime refresh path for Codex auth and usage.
2. Add a separate local metadata layer for account-specific user data.
3. Add a separate settings layer for app preferences and reminder toggles.
4. Add a separate renewal-reminder scheduling layer rather than overloading the current cooldown notification path.

This avoids premature multi-provider abstraction while still creating clean boundaries for V3.

## Domain Design

### Existing entities that remain

- `Account`
  Identity-like record for a detected account.
- `UsageSnapshot`
  Last known usage, cooldown, subscription expiry timestamp, and freshness state.
- `CurrentUsagePayload`
  Normalized runtime input from auth/API data.

### New entities

#### `AccountPriority`

Enum:

- `none`
- `primary`
- `backup`
- `auxiliary`

This is a local user preference, not provider-derived data.

#### `AccountMetadata`

Fields:

- `accountId: UUID`
- `priority: AccountPriority`
- `note: String`
- `updatedAt: Date`

Purpose:

- store user-owned metadata independently from provider-owned account identity;
- keep refresh cycles from overwriting priorities or notes.

#### `RenewalReminderSettings`

Fields:

- `days7Enabled: Bool`
- `days3Enabled: Bool`
- `days1Enabled: Bool`
- `sameDayEnabled: Bool`

Purpose:

- model the four supported renewal reminder triggers explicitly;
- avoid generalized reminder builders that would be unnecessary for V2.

#### `AppSettingsState`

Fields:

- `pollingWhenRunning: Double?`
- `pollingWhenClosed: Double?`
- `cooldownNotificationsEnabled: Bool`
- `renewalReminders: RenewalReminderSettings`

Purpose:

- centralize all user-configurable preferences in one persisted structure;
- replace scattered `UserDefaults` keys over time with one coherent settings model.

#### `SubscriptionDerivedState`

Enum:

- `active`
- `expiringSoon`
- `expired`
- `unknown`

This is derived at runtime from `subscriptionExpiresAt`, not stored as a separate source of truth.

## Persistence Design

### Persisted state shape

Extend the current persisted JSON state to include:

- `accounts`
- `snapshots`
- `accountMetadata`
- `settings`

### Migration behavior

The current `state.json` must remain readable without manual migration.

Rules:

- if `accountMetadata` is missing, default to `[]`;
- if `settings` is missing, default to V2-safe defaults;
- no destructive migration;
- no separate migration command.

### Ownership boundaries

- provider refresh updates `accounts` and `snapshots`;
- user actions update `accountMetadata` and `settings`;
- refresh must never wipe local note/priority data.

## Subscription Design

### Source of truth

Subscription expiry remains automatic only:

- use `subscriptionExpiresAt` from the current auth/API path;
- do not introduce manual override fields in V2.

### Derived status rules

- `unknown`: no expiry date
- `expired`: expiry date is in the past
- `expiringSoon`: expiry date is within `7 days`
- `active`: expiry date is more than `7 days` away

This window is fixed for V2 so the product behavior stays predictable.

## Reminder Design

### Reminder schedule

Supported reminders:

- `7 days before expiry`
- `3 days before expiry`
- `1 day before expiry`
- `same day as expiry`

### Reminder enablement

Each reminder type is independently enabled/disabled in Settings.

### Scheduling model

Renewal reminders must be scheduled independently from cooldown reminders.

Use deterministic notification identifiers:

- `renewal-<accountId>-7d`
- `renewal-<accountId>-3d`
- `renewal-<accountId>-1d`
- `renewal-<accountId>-0d`

Behavior:

- on refresh, recompute the desired reminder set for each account;
- cancel obsolete reminder notifications;
- schedule missing valid reminder notifications;
- do not schedule reminders for `expired` or `unknown` subscriptions.

### Cooldown notifications

Keep the existing cooldown notification behavior, but treat it as a separate concern from renewal reminders.

## Sorting and Presentation

### Account ordering

The dropdown list and Accounts settings list should sort by:

1. priority weight
2. snapshot freshness / most recently synced
3. display name as stable fallback

Priority weight:

- `primary`
- `backup`
- `auxiliary`
- `none`

### Account row display

Each row should be able to show:

- account display name
- provider
- current usage/cooldown status
- priority badge when not `none`
- note preview when not empty
- subscription status and expiry text when available

Examples:

- `Primary`
- `Backup`
- `Expires Apr 18`
- `Expired`

The dropdown should stay compact and readable. Editing does not happen inline there in V2.

## Settings UX

### Structure

Use a dedicated Settings window with a sidebar and three sections:

- `General`
- `Notifications`
- `Accounts`

### General

- polling interval while Codex is running
- polling interval while Codex is closed

### Notifications

- cooldown notifications toggle
- renewal reminder toggles:
  - `7 days`
  - `3 days`
  - `1 day`
  - `Same day`

### Accounts

Show a sorted account list.

For the selected account, allow:

- editing priority
- editing free-form note
- viewing provider and current subscription expiry

### Editing rules

- metadata editing happens in Settings only in V2;
- dropdown remains primarily informational and action-oriented.

## Runtime Flow Changes

### Refresh path

On each refresh:

1. fetch Codex auth/API usage payload
2. derive updated snapshot
3. persist snapshot changes
4. compute subscription derived state for presentation
5. reconcile cooldown notifications
6. reconcile renewal reminder notifications
7. publish sorted UI state

### Failure behavior

If usage fetch fails:

- keep the current stale/offline behavior from the recent fix;
- do not erase note/priority/settings state;
- do not blindly cancel renewal reminders unless expiry data truly disappeared from the latest persisted state.

## File-Level Direction

### New files

- `LimitBar/Domain/AccountPriority.swift`
- `LimitBar/Domain/AccountMetadata.swift`
- `LimitBar/Domain/AppSettingsState.swift`
- `LimitBar/Domain/SubscriptionDerivedState.swift`
- `LimitBar/App/SettingsCoordinator.swift`
- `LimitBar/Services/RenewalReminderScheduler.swift`
- `LimitBar/UI/Settings/SettingsRootView.swift`
- `LimitBar/UI/Settings/GeneralSettingsView.swift`
- `LimitBar/UI/Settings/NotificationSettingsView.swift`
- `LimitBar/UI/Settings/AccountsSettingsView.swift`

### Existing files to extend

- `LimitBar/App/AppModel.swift`
- `LimitBar/App/UsageStateCoordinator.swift`
- `LimitBar/Services/SnapshotStore.swift`
- `LimitBar/Services/NotificationManager.swift`
- `LimitBar/UI/MenuBarRootView.swift`
- `LimitBar/UI/AccountRowView.swift`
- `LimitBar/Domain/UsageSnapshot.swift`

### Tests to add or extend

- `LimitBarTests/SnapshotStoreTests.swift`
- `LimitBarTests/AppModelTests.swift`
- `LimitBarTests/SettingsCoordinatorTests.swift`
- `LimitBarTests/RenewalReminderSchedulerTests.swift`

## Non-Goals

- Claude support in V2
- full multi-provider UI
- recommendation engine for “best account to use now”
- manual subscription expiry override
- inline account editing in the dropdown
- cloud sync

## Risks and Mitigations

### Risk: metadata gets mixed into provider-owned models

Mitigation:

- keep `AccountMetadata` separate from `Account` and refresh payloads.

### Risk: notification logic becomes tangled

Mitigation:

- isolate renewal reminder scheduling into its own scheduler/coordinator.

### Risk: V2 introduces too much multi-provider abstraction too early

Mitigation:

- stay `Codex-only` in runtime implementation;
- only future-proof the data boundaries, not the whole UI/runtime stack.

### Risk: settings sprawl across `UserDefaults` and JSON state

Mitigation:

- centralize user-configurable behavior in `AppSettingsState`.

## Success Criteria

V2 is successful when:

1. accounts can be assigned a priority and note;
2. account lists sort by priority correctly;
3. subscription status is shown automatically from existing auth/API data;
4. renewal reminders are scheduled and toggled correctly;
5. settings are managed from a dedicated sidebar-based Settings window;
6. the current MVP flow remains stable and test-covered.
