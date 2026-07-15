# FitForge Risk Register

last_verified_commit: `18cb461`
last_verified_date: `2026-07-15 UTC`

| ID | Priority | Status | Area | Risk / residual exposure | Mitigation / release gate | Owner |
|---|---|---|---|---|---|---|
| R-01 | P0 | Open gate | Sync deployment | Training-sync code and migration are local only; the migration has not run against real PostgreSQL/Supabase and the feature flag defaults off. | Apply migration in a disposable project, verify RLS/FKs and two-account restore/delete/rollback, then explicitly enable the flag. | Data / Backend |
| R-02 | P0 | Mitigated locally | Training restore | Program/day/exercise slot restoration previously could not be reconstructed from remote workout rows. | Local code now syncs programs, rules, slot-aware workouts, and set logs. Keep release blocked until R-01's real database smoke passes. | Workout / Data |
| R-03 | P0 | Deferred | Pro / billing | Local Pro state is not a production entitlement and can be spoofed. | Keep development-only; integrate and verify store/RevenueCat entitlement before paid launch. | Product / Billing |
| R-04 | P1 | Closed locally | User isolation | Async handlers and imperative provider reads could update the wrong account or stale widget. | `UserScope` identity, expected-user guards, provider rebuilds, fixed save attempts, and A -> B -> A widget tests now cover the audited paths. | App |
| R-05 | P2 | Mitigated | Persistence | Lower-risk SecureStorage blobs remain unversioned. | High-risk training/program/rule/workout/set blobs now use fail-closed v1 envelopes; migrate remaining blobs incrementally. | Data |
| R-06 | P2 | Ongoing | i18n / units | New visible text can bypass `L10n`. | Audited touched screens are localized with English/Chinese tests; retain localization review for future UI changes. | UI |
| R-07 | P2 | Closed locally | CI / docs | CI previously ran fewer checks than the local gate. | Workflow now invokes `scripts/pre_push.sh`; verify the changed workflow remotely after an approved push. | Release |
| R-08 | P0 | Partially exercised | Mobile QA | The 2026-07-15 LAN fast smoke found no defect in the executed core paths, but human drag, deload variants, full scheduling/lifecycle/logging matrices, long-break recovery, and second-account isolation remain incomplete. | Keep the executed evidence as the baseline and complete the explicitly listed manual subcases before mobile release. Prefer same-LAN ADB and the same-signed 23.3 MB release APK for remote retries. | Release / UI |
| R-09 | P2 | Accepted | Local concurrency | Storage locks are single-process and multi-key persistence is not crash-atomic across process death. | Production uses one `AppDatabase` singleton; reconsider transactional storage if background isolates or stronger crash guarantees are introduced. | Data |
| R-10 | P2 | Open | Sync conflicts | Snapshot pull/outbox behavior prevents known overwrite races but does not provide user-visible conflict resolution for concurrent devices. | Keep default-off until activation smoke; define conflict UX if latest-write-wins proves insufficient. | Product / Data |

## Priority Summary

- P0 gates/deferred: R-01, R-03, R-08.
- Locally mitigated but activation-dependent: R-02.
- Closed locally: R-04, R-07.
- Accepted or ongoing P2: R-05, R-06, R-09, R-10.
