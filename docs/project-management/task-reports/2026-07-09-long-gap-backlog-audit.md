# Long-Gap Recovery Backlog Audit

last_verified_commit: `79d65df`
last_verified_date: `2026-07-09 UTC`

## Summary

Audited the P1 backlog item for adding a long-gap recovery prompt. Live code already implements the feature for workout prescriptions after more than 7 days away from the same program exercise slot. The remaining work is test hardening and mobile smoke execution, not new feature implementation.

## Agent Report: long-gap audit

- Task: Verify whether "Add long-gap recovery prompt when returning after a long break from a program slot" is implemented.
- Scope: Read-only audit of provider logic, workout UI, localization, tests, and project docs.
- Files inspected: `lib/providers/app_providers.dart`, `lib/data/models/training_program.dart`, `lib/data/repositories/app_database.dart`, `lib/features/workout/screens/workout_day_screen.dart`, `lib/core/localization/l10n.dart`, `test/features/training_program_test.dart`, `docs/project-management/BACKLOG.md`, `docs/project-management/ROADMAP.md`, `docs/project-management/TRAINING_PROGRAM_SMOKE_CHECKLIST.md`.
- Files changed: None by worker.
- Key findings: The feature is already implemented. The provider looks up the last log for the same `programId` and `programExerciseId`, marks prescriptions when `daysSinceLastLog > 7`, and the workout UI offers both a row-level long-break prompt and an Add All recovery dialog.
- Decisions / assumptions: "Returning after a long break from a program slot" is treated as workout-prescription behavior for a program exercise slot, not a modal shown specifically when tapping Resume Program.
- Tests run: None by worker; read-only audit only.
- Risks: Existing tests cover recovery fields/copy/JSON but not provider threshold behavior or widget prompt/dialog behavior. Manual smoke TP-11/TP-12 remains unchecked.
- Follow-ups: Replace the active feature item with regression-test hardening, keep mobile smoke execution as P0, and update roadmap wording from implementation to coverage.
- Evidence: Recovery metadata and `shouldOfferRecoveryLoad` exist in `WorkoutPrescription`; provider computes `daysSinceLastLog`; `workout_day_screen.dart` displays recovery actions; English and Chinese L10n keys exist.

## Main Integration

- Updated `BACKLOG.md` so long-gap recovery is no longer listed as an unimplemented feature.
- Updated `ROADMAP.md` to track long-gap smoke and regression coverage.
- Updated `RISK_REGISTER.md` with the current mobile-test-environment gap.
- Updated `INDEX.md` to include this task report.

## Verification

- `flutter devices` found only Linux desktop and Chrome Web targets.
- `flutter emulators` reported no emulator sources or Android AVD images.
- No production code changed in this task.
