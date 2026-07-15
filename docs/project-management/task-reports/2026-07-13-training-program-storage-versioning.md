# Training Program Storage Versioning

last_verified_commit: `18cb461`
task_status: `complete`
owner: `fitforge-general-contractor`
created_at: `2026-07-13 UTC`
updated_at: `2026-07-13 UTC`

## Summary

Added a schema-v1 envelope for the user-scoped `training_programs` SecureStorage blob while preserving legacy top-level arrays. Existing valid legacy data remains read-only until the next successful program mutation, which writes v1. Unknown versions, corrupt payloads, invalid items, and cross-user owners fail closed without modifying the original bytes.

## Storage Contract

- Key remains `$userId:training_programs`.
- New format is `{"schemaVersion":1,"data":[...]}`.
- Model `toJson/fromJson` formats are unchanged; nested `periodWeeks` remains legacy-read-only and rewrites as `periodCycles` on the next save.
- Missing key and empty-user reads return an empty list without creating storage.
- Empty-user or owner-mismatched writes are rejected.
- Legacy reads have no write side effect; the next successful save, append, delete, activate, end, or advancement writes v1.
- Future schema and corrupt data throw typed exceptions, preserve raw bytes, and block bulk replacement.

## Agent Report: architecture auditor

- Task: Define the minimum backwards-compatible storage versioning boundary.
- Scope: Read-only AppDatabase/model/provider/test audit.
- Files changed: None.
- Key findings: SecureStorage contains many unrelated root shapes, so a global version or all-blob migration would be high risk. `training_programs` is the best first slice because its models continue to gain fields and it already has a realistic legacy fixture.
- Decisions / assumptions: Use a per-blob v1 envelope, no read-time rewrite, explicit fail-closed exceptions, and user-owner validation. Defer `workout_set_logs` to the next slice.
- Tests run: None.
- Risks: Old builds cannot read the v1 envelope after a new write; read-modify-write concurrency remains non-atomic.
- Follow-ups: Extend the contract incrementally to set logs and other high-risk blobs.

## Agent Report: implementation worker

- Task: Implement the training-program v1 envelope and write-path protection.
- Scope: `lib/data/repositories/app_database.dart` only.
- Files changed: `app_database.dart`.
- Key findings: The repository previously decoded and wrote raw lists directly; delete also had a separate raw write.
- Decisions / assumptions: Centralize v1 writes, keep existing active-program normalization semantics, and leave models/other blobs untouched.
- Tests run: Focused analyze and diff checks passed.
- Risks: Typed storage exceptions need deliberate UI/provider propagation rather than silent empty fallback.
- Follow-ups: Add recovery UX only as a separate product decision.

## Agent Report: test worker

- Task: Add focused migration, corruption, future-version, ownership, and isolation regression coverage.
- Scope: New `test/data/app_database_storage_versioning_test.dart` only.
- Files changed: `app_database_storage_versioning_test.dart`.
- Key findings: Existing tests mostly use public APIs; only one training-program fixture directly used the legacy raw array.
- Decisions / assumptions: Use fixed inactive fixtures and raw SecureStorage reads so tests are deterministic and verify exact outer format.
- Tests run: 20 focused tests passed after review fixes.
- Risks: FlutterSecureStorage singleton mocks cannot simulate write failure or compare-and-swap races.
- Follow-ups: Add account-switch provider coverage in the adjacent user-isolation P1.

## Agent Report: independent reviewer

- Task: Review storage/data-loss behavior, tests, Gradle settings, and documentation.
- Scope: Read-only final-diff review.
- Files changed: None.
- Key findings: One P1 blocker found: public bulk save could overwrite an existing future/corrupt raw blob without first reading it. P2 findings covered provider error visibility, host-specific Gradle settings, unrelated-blob sentinel coverage, and stale docs.
- Decisions / assumptions: The fail-closed contract applies to every public mutation, even if current production callers usually read first.
- Tests run: None.
- Risks: Some active-plan providers still convert storage errors into no-plan results.
- Follow-ups: The P1 was fixed with read-before-write validation; future/corrupt bulk-save tests and an unrelated-key sentinel were added. Host Gradle limits moved out of the repository.

## Main Integration

- Verified and fixed the review P1 before final validation.
- Kept the repository-wide Android Gradle configuration unchanged; low-memory settings live in host-local `~/.gradle/gradle.properties`.
- Updated the backlog, decision log, risk register, roadmap, quality gates, and task index.

## Verification

- New storage suite: 20 tests passed.
- Combined storage/training/wording/detail/recovery suite: 129 tests passed.
- `flutter analyze --no-fatal-infos --no-fatal-warnings`: passed with the repository's 10 existing info findings and no warnings or errors.
- `scripts/pre_push.sh`: passed analyzer, full Flutter tests, widget dump, and dead-button checks.
- Independent re-review: the original P1 is closed with no remaining P0/P1 finding.

## Remaining Risk

- `workout_set_logs` and other JSON blobs remain unversioned.
- Provider consumers using `valueOrNull ?? []` can hide storage errors as an empty active plan.
- SecureStorage writes are not transactional, so concurrent read-modify-write races remain outside this slice.
