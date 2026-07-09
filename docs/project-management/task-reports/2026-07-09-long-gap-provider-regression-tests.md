# Long-Gap Provider Regression Tests

last_verified_commit: `750c2b2`
last_verified_date: `2026-07-09 UTC`

## Summary

Added provider-level regression tests for the existing long-gap recovery behavior in `workoutPrescriptionsForDateProvider`. The tests cover the `> 7` day threshold, exact 7-day non-trigger, latest same-slot log selection, same program/exercise-slot scoping, and user isolation.

## Agent Report: long-gap test worker

- Task: Implement focused regression tests for long-gap recovery prompt behavior.
- Scope: Tests only; no production code changes.
- Files inspected: `test/features/training_program_test.dart`, `lib/providers/app_providers.dart`, `lib/data/repositories/app_database.dart`, `lib/data/models/training_program.dart`, `lib/data/models/workout_log.dart`.
- Files changed: `test/features/training_program_test.dart`.
- Key findings: `workoutPrescriptionsForDateProvider` already gates recovery at `daysSinceLastLog > 7` and looks up last logs by `programId` plus `programExerciseId`.
- Decisions / assumptions: Added provider/domain tests in the existing training-program test file; seeded `FlutterSecureStorage` through existing `AppDatabase` helpers; used a `ProviderContainer` override for `currentUserIdProvider`; widget/dialog coverage remains separate.
- Tests run: `flutter test test/features/training_program_test.dart` passed in the worker with 98 tests before reviewer follow-up additions.
- Risks: Worker coverage was provider-level, not UI dialog-level.
- Follow-ups: Add widget tests for row-level prompt and Add All planned-vs-last-load dialog when the screen harness is practical.
- Evidence: Worker added tests for stale recovery, exact 7 days, and same-program/same-slot scoping.

## Agent Report: long-gap test reviewer

- Task: Review uncommitted provider-level long-gap recovery tests.
- Scope: Test diff, Riverpod provider behavior, database lookup, model recovery flag.
- Files inspected: `test/features/training_program_test.dart`, `lib/providers/app_providers.dart`, `lib/data/repositories/app_database.dart`, `lib/data/models/training_program.dart`.
- Files changed: None by reviewer.
- Key findings: No blocking findings. Reviewer identified a missing latest-same-slot-log edge case and a lower-priority cross-user fixture gap.
- Decisions / assumptions: Treat provider tests as sufficient for this slice; UI prompt/dialog tests remain a follow-up.
- Tests run: `git diff --check -- test/features/training_program_test.dart`; reviewer could not run Flutter because `flutter` was not on that worker PATH.
- Risks: UI dialog behavior still needs widget/manual coverage.
- Follow-ups: Add widget regression tests for the row prompt and Add All choice.
- Evidence: Reviewer pointed to provider lookup in `app_providers.dart`, newest-first sorting in `app_database.dart`, and `shouldOfferRecoveryLoad` threshold in `training_program.dart`.

## Main Integration

- Added reviewer-requested tests for latest same-slot log selection and cross-user isolation.
- Updated `BACKLOG.md` so the remaining P1 item is widget/dialog coverage only.
- Updated `ROADMAP.md` to reflect provider coverage completion.
- Updated `INDEX.md` to include this task report.

## Verification

- `dart format test/features/training_program_test.dart` passed.
- `flutter test test/features/training_program_test.dart` passed with 100 tests.
- `flutter analyze --no-fatal-infos --no-fatal-warnings` passed with the known 10 info-level baseline.
- `bash scripts/pre_push.sh` passed: analyze baseline, full test suite, widget dump, and dead button check.
- `git diff --check` passed.
