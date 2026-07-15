# P1 Stabilization And Training-Sync Foundation

date: `2026-07-13 UTC`
base_commit: `18cb461`
status: `verified locally; included in the 2026-07-15 approved push batch`

## Scope

The user deferred P0 mobile checklist item 1 and production Pro entitlement item 4. This batch addressed the remaining audit findings across sync durability, storage, user isolation, auth/onboarding, provider errors, localization, domain extraction, CI, analyzer health, and release size evidence.

No commit, push, migration deployment, feature-flag enablement, or Pages deployment was performed.

## Implemented

- Stable auth routing distinguishes loading, error, onboarding, and authenticated profiles without accepting a stale profile from another account.
- Auth transitions initialize scoped caches/sync through a testable handler; login no longer reads a disposed `WidgetRef` after Supabase awaits.
- Account-scoped providers and dialogs use `UserScope` identity, including A -> B -> A invalidation.
- Workout drafts bind to their originating scope. Saving is single-flight, uses a fixed retry plan/UUIDs, completes captured local bundles safely, freezes drafts during retries, and prevents old edit/delete dialogs from touching a new account.
- Rest-day advancement is single-flight; dialog controllers are owned by their widgets or removed.
- Training-program and workout-day screens were structurally split. Pure helpers validate all-null/all-nonblank program slots and retire linked deload days safely when a source becomes rest.
- Training programs, progression rules, workout logs, and workout set logs use user-owned v1 storage envelopes with legacy compatibility and fail-closed corruption/future-version handling.
- Same-key read-modify-write operations are serialized in process. Workout/set operations use `workout -> set -> outbox`; parent deletion cannot race an orphan set back into storage.
- Feature-gated training sync adds slot-aware program/rule/workout/set APIs, typed row codecs, a tokenized compact outbox, durable per-domain recovery IDs, tombstones, snapshot restore, quarantine, and serialized account-aware sync runs.
- Recovery handles enabled -> disabled -> enabled edits and outbox write failures. Fresh default-disabled installs do not accumulate outbox/recovery metadata.
- Same-ID workout retries are idempotent; exercise/program slot identity cannot change while child sets exist.
- The additive migration defines tables/columns, checks, owner/slot FKs, triggers, indexes, and RLS policies. It remains undeployed and the feature flag defaults false.
- Touched UI error states and visible copy were localized in English/Chinese. Provider/storage failures surface retry UI instead of silently becoming empty data.
- Pages CI now invokes `scripts/pre_push.sh`. Strict analyzer issues were reduced to zero.

## Independent Review

Delegated implementation and separate read-only reviews covered sync/storage, auth/provider lifecycle, and training domain invariants. Confirmed review findings were fixed in multiple loops:

- stale bootstrap and local-write/outbox failure recovery
- syncable set -> local-only tombstones and cascade/save races
- same-ID workout/set slot consistency
- stale auth profile classification and A -> B -> A dialog writes
- workout draft ownership, partial retry duplication, save/rest single-flight
- blank slot identifiers and linked deload cleanup
- controller disposal during dialog route transitions and async context analyzer warnings

Final read-only sync review reported no remaining finding after the same-ID slot fix. Final UI findings were repaired and covered by the last focused tests.

## Verification

- Integrated focused suite: 86/86 passed.
- Final `workout_day_user_scope_test.dart`: 11/11 passed.
- Sync outbox focused suite after final slot fix: 24/24 passed.
- Additional delegated combinations: sync/high-risk storage 57/57; training/workout recovery 104/104.
- `/home/dyy/flutter/bin/flutter analyze --no-pub`: no issues found.
- `bash scripts/pre_push.sh`: all passed.
- Widget dump: `+ Add Workout` pill 130x46, `Today` pill 130x29, one AppBar, zero `person_outline` icons.
- Dead-button scan: zero.
- `git diff --check`: clean.
- Reference release arm64 APK baseline recorded before the final UI/storage refinements: 23,255,260 bytes; SHA-256 `4146bf58c8abd2c9a872fde3f03d40fd2de942e276987917c8ea463b38725c7f`. The final worktree was not rebuilt into a release APK.

## Remaining Gates / Risks

- Full phone/emulator checklist is deferred; automated tests do not replace touch/drag/navigation/device evidence.
- Production Pro entitlement is deferred.
- The migration has only static/local coverage. Real PostgreSQL/Supabase migration, RLS/FK, and two-account restore/delete/rollback smoke are mandatory before enabling sync.
- Training sync remains default-off through `FITFORGE_TRAINING_SYNC_V1=false`.
- Mutation locks are process-local; cross-process/crash-atomic storage and richer multi-device conflict UX remain P2 decisions.

## Agent Report: General Contractor Synthesis

- Task: Fix all non-deferred stabilization audit items.
- Scope: Auth, providers, storage, sync, training/workout UI/domain, i18n, CI, tests, and governance docs.
- Files changed: Broad stabilization/sync batch; see its commit history and task
  report sections.
- Key findings: Local code gates are green; operational sync activation and the two explicitly deferred P0 items remain.
- Decisions / assumptions: Default-off schema-first sync; repository push does
  not deploy the migration or enable the capability.
- Tests run: Focused, strict analyze, and complete pre-push gates as listed above.
- Risks: Real device and real database validation remain release gates.
- Follow-ups: Resume mobile smoke, deploy/test the migration in a disposable project, then make an explicit flag decision.
- Evidence: Local command results, reviewed final diff, and the 2026-07-15
  approved push gate.
