# Long-Gap Widget Regression Tests

last_verified_commit: `b8d3a28`
task_status: `complete`
owner: `fitforge-general-contractor`
created_at: `2026-07-09 UTC`
updated_at: `2026-07-09 UTC`

## Summary

Added widget-level regression coverage for the existing long-gap recovery UI in `WorkoutDayScreen`. The tests build the real screen with local `AppDatabase` seed data, trigger the row-level recovery prompt, and exercise the Add all recovery dialog choices.

## Agent Report: widget-test implementation worker

- Task: Add regression coverage for long-gap recovery UI in `WorkoutDayScreen`.
- Scope: Tests only; no production code or public docs changed.
- Files inspected: `workout_day_screen.dart`, `training_program.dart`, `app_providers.dart`, `app_database.dart`, `l10n.dart`, `test_helpers.dart`, existing provider tests in `training_program_test.dart`.
- Files changed: `test/screens/workout_day_screen_recovery_test.dart`.
- Key findings: Existing UI exposes stable visible text for the row prompt, Add all dialog, and pending chips, so no production keys or semantics hooks were required.
- Decisions / assumptions: Seeded user `test`, active program on `2025-06-20`, and same-slot stale log from `2025-06-12`. Last logged values are `4x12 82.5 kg`; planned double-progression values are `4x8 85.0 kg`.
- Tests run: Dart format passed; direct Dart analysis passed. The worker sandbox could not execute Flutter tests because the Flutter SDK cache was read-only there.
- Risks: Worker could not execute the focused widget test inside its isolated sandbox.
- Follow-ups: Main verification must run the focused Flutter test in the primary environment.
- Evidence: Initial worker tests covered row-level "Use last time", Add all "Use plan", and Add all "Use last time".

## Agent Report: independent reviewer

- Task: Review the uncommitted long-gap recovery widget tests.
- Scope: Read-only review of `test/screens/workout_day_screen_recovery_test.dart` and the production widget/provider/database paths it exercises.
- Files inspected: `test/screens/workout_day_screen_recovery_test.dart`, `lib/features/workout/screens/workout_day_screen.dart`, `lib/providers/app_providers.dart`, `lib/data/repositories/app_database.dart`, `lib/core/utils/program_prescription_calculator.dart`.
- Files changed: None.
- Key findings: No blocking findings. The tests seed through `AppDatabase`, match the production provider path, and meaningfully distinguish planned values from last logged values.
- Decisions / assumptions: The mixed stale/non-stale Add all case was useful but non-blocking.
- Tests run: None by reviewer; read-only review only.
- Risks: Remaining confidence gap before main integration was the mixed Add all case.
- Follow-ups: Add a mixed stale/non-stale test if low-cost.
- Evidence: Reviewer verified `_addProgramPrescription`, `_addAllProgramPrescriptions`, `workoutPrescriptionsForDateProvider`, and the double-progression max-rep branch.

## Main Integration

- Added a fourth widget test for mixed Add all behavior: when the user chooses last logged values, only stale prescriptions use recovery values and non-stale prescriptions keep planned values.
- Updated `BACKLOG.md` to remove the completed widget/dialog regression item.
- Updated `ROADMAP.md` so long-gap recovery now only calls out mobile manual smoke.
- Updated `INDEX.md` to include this task report.

## Verification

- `/home/dyy/flutter/bin/cache/dart-sdk/bin/dart format test/screens/workout_day_screen_recovery_test.dart` passed.
- `/home/dyy/flutter/bin/cache/dart-sdk/bin/dart analyze test/screens/workout_day_screen_recovery_test.dart` passed.
- `env NO_PROXY=localhost,127.0.0.1 no_proxy=localhost,127.0.0.1 /home/dyy/flutter/bin/flutter test test/screens/workout_day_screen_recovery_test.dart` passed with 4 widget tests.
- `bash scripts/pre_push.sh` passed: analyze baseline, full test suite, widget dump, and dead button check.
- `git diff --check` passed.

## Remaining Risk

- Mobile manual smoke remains blocked until a real device or Android emulator is available.
