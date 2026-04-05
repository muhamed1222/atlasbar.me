# Daily Reset Recovery Design

## Goal

Make `LimitBar` automatically recover Codex daily session availability when `nextResetAt` passes, even if the user has already switched to another account or restarted the app.

Target user experience:

- an account can sit at `0%` session remaining with a known `nextResetAt`;
- when that reset time arrives, the account becomes usable again without manual refresh;
- the session gauge visually recovers;
- the app persists the recovered state to disk;
- the user receives a notification that the account is available again.

This design is for `daily session recovery` only. Weekly usage and subscription data remain server-driven.

## Product Decisions

- Recovery scope: `daily session only`
- Recovery trigger: `local time-based transition at nextResetAt`
- Recovery source of truth: `predicted locally until next server refresh confirms or corrects it`
- Notification behavior: `send one cooldown-ready notification when local recovery fires`
- Persistence behavior: `recovered state must survive restart`
- Weekly behavior: `do not locally restore weekly quota`
- Subscription behavior: `do not locally change subscription state`

## Current Problem

Today the app already knows `nextResetAt` and can schedule a cooldown notification, but it does not fully recover the account state when that time passes.

Current gaps:

- the account may still appear exhausted or stale until a later refresh happens;
- the `Сессия` gauge does not recover itself locally;
- restart or account switching can leave the user with stale-looking cards even after reset time passed;
- notifications and card state are not driven by a shared reset-recovery rule.

## Root Cause

The current architecture treats `nextResetAt` mostly as a display and notification field.

What is missing is a real `time-based state transition`:

- no runtime scheduler that wakes up at the next reset boundary;
- no domain rule that converts an exhausted/coolingDown snapshot into an available snapshot when reset time has passed;
- no persisted marker that distinguishes a server-fetched state from a locally predicted recovery.

## Alternatives Considered

### Option 1: Notification only

At `nextResetAt`, only send a notification and wait for the next real refresh to update UI.

Pros:

- simplest behavior;
- no risk of local/server mismatch.

Cons:

- weak UX;
- card can still show `0%` after the app tells the user the account is ready.

### Option 2: Local recovery only

At `nextResetAt`, locally restore daily session state immediately and persist it.

Pros:

- matches user expectation;
- works across account switches and restart;
- minimal additional networking complexity.

Cons:

- short-lived mismatch is possible if the backend has not yet reflected the reset.

### Option 3: Local recovery plus immediate targeted revalidation

At `nextResetAt`, locally restore state and then try to revalidate it by fetching fresh usage.

Pros:

- best long-term accuracy;
- shortest mismatch window.

Cons:

- significantly more orchestration complexity;
- multi-account targeted refresh design is not in place yet.

## Recommended Design

Implement `Option 2` now.

That means:

1. use `nextResetAt` to drive a local recovery event;
2. immediately restore daily session usability locally;
3. persist the recovered snapshot;
4. send the cooldown-ready notification once;
5. let the next normal server refresh overwrite local prediction if needed.

This gives the user the expected behavior without expanding the refresh system again right now.

## Domain Design

### UsageSnapshot additions

Add a persisted field to [UsageSnapshot.swift](/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/Domain/UsageSnapshot.swift):

- `stateOrigin`

Enum values:

- `server`
- `predictedReset`

Purpose:

- distinguish a normal API snapshot from a locally recovered one;
- allow future reconciliation logic to reason about how the current state was produced.

### Recovery rule

An account qualifies for local recovery when all of these are true:

- `nextResetAt` exists;
- `nextResetAt <= now`;
- snapshot is currently not usable (`exhausted`, `coolingDown`, or `stale`);
- snapshot has daily quota data (`sessionPercentUsed != nil`).

When recovery fires, mutate only these fields:

- `sessionPercentUsed = 0`
- `usageStatus = .available`
- `stateOrigin = .predictedReset`
- `lastSyncedAt = now`

Do not mutate:

- `weeklyPercentUsed`
- `weeklyResetAt`
- `subscriptionExpiresAt`
- `planType`

## Scheduler Design

Introduce a focused `DailyResetRecoveryCoordinator`.

Responsibilities:

- scan all snapshots for the soonest eligible `nextResetAt`;
- schedule exactly one in-memory timer for the earliest reset boundary;
- when the timer fires, recover all eligible accounts whose reset time is now in the past;
- after applying recovery, persist state, refresh menu bar presentation, and schedule the next timer.

Non-responsibilities:

- fetching from providers;
- deciding notification authorization;
- editing UI directly.

### Why a dedicated coordinator

Putting this directly into `AppModel` would re-grow `AppModel` after recent cleanup. A dedicated coordinator keeps the logic isolated and testable.

## App Flow

### On app launch

1. load persisted state;
2. run immediate `recovery reconciliation` against `now`;
3. if any snapshots should already be recovered, apply recovery before showing final UI;
4. schedule the next future reset timer.

### After every refresh

1. apply provider refresh as today;
2. run `recovery reconciliation` again in case:
   - a reset passed while refresh was running;
   - a payload removed or changed `nextResetAt`;
   - server now confirms a previously predicted reset;
3. reschedule next timer.

### When timer fires

1. recover all eligible snapshots;
2. persist updated state;
3. refresh compact label and menu bar state;
4. send cooldown-ready notifications for newly recovered accounts;
5. schedule next timer.

## Notification Design

Notification behavior should remain one-shot per reset boundary.

Rules:

- if the timer causes a real local recovery, send the cooldown-ready notification then;
- if notifications are disabled, still recover state, but skip notification delivery;
- do not send duplicate notifications when:
  - the app restarts after reset time already passed;
  - a later refresh sees the same recovered account;
  - `reconcileCooldownNotifications()` runs again.

Implementation note:

Use the recovery transition itself as the event boundary. The notification should be tied to `transitioning into recovered availability`, not simply to `nextResetAt existing`.

## Persistence Design

Recovered snapshots must be written to the same `state.json`.

Why:

- the user can quit and reopen the app after reset time;
- switched-away accounts still need to look correct when shown later;
- notification dedupe is simpler if the recovered state is already persisted.

Compatibility:

- missing `stateOrigin` in older snapshots should decode as `server`;
- recovery should not require a destructive migration.

## UI Rules

After local recovery:

- `Сессия` gauge must show full remaining capacity again;
- account should no longer look blocked;
- `Ежедневная` remains the reset time that just passed;
- `Еженедельная` and `Подписка` remain unchanged.

Optional future improvement:

- small subtle indicator that the row is currently locally recovered rather than freshly server-confirmed.

This is not required for the first implementation.

## Server Reconciliation

Server payload remains authoritative.

Rule:

- the next real provider refresh can overwrite a `predictedReset` snapshot fully.

This keeps the local recovery model simple:

- local prediction makes the app useful immediately;
- normal refresh path restores server truth without special merge gymnastics.

## Testing Plan

Add tests for:

1. `nextResetAt` in the future schedules the next recovery timer.
2. `nextResetAt` in the past on launch recovers immediately.
3. exhausted snapshot becomes available when recovery fires.
4. `sessionPercentUsed` is reset to `0 used`.
5. weekly and subscription fields remain unchanged.
6. recovered state persists and reloads correctly.
7. one notification is sent per recovery transition.
8. disabled notifications still allow local recovery.
9. next provider refresh can overwrite `predictedReset` with server data.

## Scope Boundaries

Included:

- local daily-session recovery
- persistence of recovered state
- notification-on-recovery
- timer scheduling and re-scheduling

Excluded:

- weekly local recovery
- targeted provider refresh after recovery
- UI badges for `predictedReset`
- broader notification system refactor

## Acceptance Criteria

- an exhausted account with a known future `nextResetAt` becomes usable when that time passes even if another account is active;
- the `Сессия` gauge recovers without a manual refresh;
- the app persists the recovered state and shows it correctly after restart;
- one availability notification is delivered when recovery happens;
- the next normal refresh can replace the predicted state with server truth.
