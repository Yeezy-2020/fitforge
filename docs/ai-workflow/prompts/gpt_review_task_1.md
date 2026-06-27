# GPT Review Task 1: Training Program Domain Skeleton

Review the uncommitted diff for the FitForge Flutter/Riverpod repository.

## Review Stance

Prioritize correctness and regressions over style. Findings should be concrete,
with file and line references where possible. If there are no blocking issues,
say so clearly and list residual risks.

## What Changed

The implementation should add the first MVP slice of a training-program-based
progressive overload system:

- domain models for `TrainingProgram`, `ProgramDay`, `ProgramExercise`,
  `ProgressionScheme`, `WorkoutPrescription`, and `WorkoutSetLog`
- local secure-storage methods in `AppDatabase`
- Riverpod providers for training programs and active training program
- focused model tests

## Must Check

- New user-scoped providers use `ref.watch(currentUserIdProvider)` in `build`
  so account switches do not show stale programs.
- Local storage keys are user-scoped through the existing `_key(userId, type)`
  helper.
- JSON parsing tolerates missing or unknown enum values without crashing.
- `setActiveTrainingProgram` leaves at most one active program per user.
- `advance current day` handles empty programs and rest days without crashing.
- The implementation does not connect Supabase or alter unrelated sync/auth
  behavior.
- Existing `ProgressionRule` and `ProgressionCalculator` behavior is not broken.
- Tests cover core model serialization and plan-cycle behavior.

## Output Format

Return:

1. Findings, ordered by severity.
2. Open questions or assumptions.
3. Test gaps or commands that still need to run.
4. Short overall verdict: accept, accept with follow-ups, or reject.
