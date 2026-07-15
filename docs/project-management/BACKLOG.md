# FitForge Backlog

last_verified_commit: `18cb461`
last_verified_date: `2026-07-15 UTC`

## P0

- **Partial real-device release gate:** The 2026-07-15 LAN fast smoke passed
  creation, finite/continuous summaries, exercise CRUD, standard deload and
  linked-weight refresh, activation replacement, pause/resume, Add all/save/
  advance, Chinese/lb, restart, rotation, and crash/ANR checks. Complete the
  remaining manual matrix: human long-press reorder, volume/custom deloads,
  source add/remove refresh, current-plus-future date rollover, earlier/end
  lifecycle, TP-10 non-happy paths, TP-11 long-break, and second-account TP-13.
- **Training-sync activation gate:** Apply `202607130001_training_sync_foundation.sql` to a disposable real Supabase/PostgreSQL environment, verify RLS/FKs with two accounts, run restore/upsert/delete/offline-rollback smoke, then explicitly enable `FITFORGE_TRAINING_SYNC_V1`. The code foundation is complete locally, but production activation is intentionally blocked while the migration is undeployed and the flag defaults off.
- **Deferred by user:** Replace the development-only local Pro unlock with store/RevenueCat entitlement verification before paid launch.

## P1

- No known open code defect remains from the 2026-07-13 stabilization audit. Reopen an item only with reproducible evidence from device smoke, CI, or production-like sync validation.
- After sync activation testing, address any schema/RLS incompatibility before enabling the capability for users.

## P2

- Feature: Google and Apple login.
- Data reliability: version lower-risk SecureStorage blobs that are still raw JSON.
- Data reliability: decide whether cross-process storage mutation or crash-atomic persistence is required; current mutation locks are in-process and production uses the `AppDatabase` singleton.
- Sync: define explicit multi-device conflict UX beyond latest-write-wins snapshots.
- Maintainability: split the 2.1k-line `AppDatabase` and 1.2k-line provider module after activation behavior is stable.
- Release: track the arm64 release APK baseline and investigate meaningful growth before packaging.
- Dependencies: plan major package upgrades separately; current constraints intentionally remain unchanged.

## Completed In 2026-07-15 Batch

- Onboarding/profile error routing, localization, provider error propagation, and account-scoped cache resets.
- Async A -> B -> A guards, fixed workout save plans, single-flight workout/rest-day actions, and dialog lifecycle fixes.
- High-risk v1 envelopes for training programs, progression rules, workout logs, and workout set logs.
- In-process read-modify-write locks and workout/set parent consistency checks.
- Training-program editor and workout-log builder domain helpers, including blank-slot and linked-deload invariants.
- Feature-gated training sync with tokenized outbox, durable recovery metadata, tombstones, snapshot restore, quarantine, RLS migration, and rollback recovery.
- CI workflow reuse of `scripts/pre_push.sh`, strict analyzer cleanup, and release APK size baseline.

## Not Now

- Do not treat Web/GitHub Pages as a supported product platform; it remains an internal preview.
- Do not enable the training-sync flag before the real database activation gate passes.
- Do not expand into AI coaching or advanced periodization UX before mobile smoke and sync activation are complete.
