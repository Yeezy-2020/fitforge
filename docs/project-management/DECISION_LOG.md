# FitForge Decision Log

last_verified_commit: `18cb461`
last_verified_date: `2026-07-13 UTC`

| Date | Decision | Rationale | Consequences | Source |
|---|---|---|---|---|
| 2026-07-09 | Keep FitForge formally mobile-only; use Web/GitHub Pages only for internal preview. | Android/iOS are the product targets while Web remains useful for CI. | Web builds stay healthy, but Web UX does not drive scope. | `README.md`, `QUALITY_GATES.md` |
| 2026-07-09 | Use `docs/project-management/` as the durable management knowledge base; code/tests/git remain higher truth. | Long-running delegated work needs stable, reviewable context. | Non-trivial changes update task reports and impacted governance docs. | `INDEX.md`, contractor skill |
| 2026-07-09 | Keep `HANDOFF.md` uncommitted and temporary. | Handoff context becomes stale quickly. | Durable facts belong here; secrets and transient context do not. | `.gitignore`, `INDEX.md` |
| 2026-07-09 | Use cycle-neutral training terminology and retain `periodWeeks` only as legacy JSON read compatibility. | Program advancement is plan-cycle based, not natural-week based. | New writes use `periodCycles`; wording guard prevents regression. | Training model/tests |
| 2026-07-13 | Version high-risk SecureStorage blobs independently with fail-closed v1 envelopes. | A global version couples unrelated formats; silent empty fallback can overwrite recoverable data. | Programs, rules, workout logs, and set logs validate schema/owner; legacy reads upgrade only on mutation. | `app_database.dart`, storage tests |
| 2026-07-13 | Introduce training sync schema-first behind `FITFORGE_TRAINING_SYNC_V1`, default false. | Remote behavior must not activate before schema/RLS verification. | Local outbox/restore code can land safely; migration deployment and flag enablement are separate release gates. | `training_sync.dart`, migration, `sync_service.dart` |
| 2026-07-13 | Use a compact tokenized outbox plus per-user/per-domain durable recovery IDs. | A domain write can succeed before outbox persistence, and rollback periods must not lose later mutations. | Bootstrap reconstructs upserts/tombstones from local truth; stale remote replacement is blocked while recovery exists. | `app_database.dart`, outbox tests |
| 2026-07-13 | Use fixed lock order `workout -> set -> outbox` and treat a workout's exercise/program slot as immutable while child sets exist. | Cascade/save races and same-ID retries can otherwise create orphans or slot mismatches. | Same-ID metric retries are idempotent; identity changes fail before metadata/domain writes. | `app_database.dart`, sync review/tests |
| 2026-07-13 | Bind async UI mutations and workout drafts to `UserScope` identity, not only user ID. | A -> B -> A can reuse the same ID while invalidating old interactions. | Dialogs, save plans, provider updates, and cache/UI publication require the original scope identity; retries reuse fixed IDs. | Auth/Workout screens and tests |
| 2026-07-13 | Reuse `scripts/pre_push.sh` in Pages CI and keep strict analyzer clean locally. | Local and remote checks should not diverge silently. | Workflow now runs tests, analyzer, widget dump, and dead-button scan before Web build; remote verification waits for an approved push. | `.github/workflows/deploy.yml` |
| 2026-07-13 | Defer full mobile smoke and production Pro entitlement work. | The phone is unavailable and the user explicitly deferred P0 items 1 and 4. | These remain release gates and are not represented as completed by automated tests. | User direction, `BACKLOG.md` |
