# Claude Task 4: Workout Completion and Program Advance

You are working in `/home/dyy/fitforge`, a Flutter/Riverpod fitness app.

## Goal

Add the fourth MVP slice for training-program-based progressive overload:
when a user saves a workout that came from the active program's current
training day, persist local `WorkoutSetLog` records and advance the active
program to the next day.

Keep this scoped. Do not touch Supabase sync for training programs.

## Existing Context

- Training program models are in `lib/data/models/training_program.dart`.
- Local storage methods exist in `lib/data/repositories/app_database.dart`,
  including `saveWorkoutSetLogs`.
- Program providers exist in `lib/providers/app_providers.dart`, including
  `trainingProgramsProvider`, `activeTrainingProgramProvider`, and
  `workoutPrescriptionsForDateProvider`.
- Workout entry screen is:
  - `lib/features/workout/screens/workout_day_screen.dart`
- Current planned suggestions call `_addToPending(...)`.
- Current `_saveAll()` writes aggregate `WorkoutLog`s locally and to Supabase.

## Required Behavior

### Pending metadata

Extend the pending workout item model so a pending item may remember where it
came from:

- `programId`
- `programDayId`
- `programExerciseId`

Manual entries must keep those fields `null`.

When the user taps a planned suggestion's "Add" or "Add all", preserve the
metadata from `WorkoutPrescription` in the pending item.

Existing manual exercise picker, custom exercise, templates, and old
exercise-level progression suggestions must continue to work and must not
pretend to be program-derived.

### Saving workout set logs

When `_saveAll()` saves a pending item that has program metadata:

- create one local `WorkoutSetLog` per set in that aggregate `WorkoutLog`.
- use the saved `WorkoutLog.id` as `workoutLogId`.
- copy `programId`, `programExerciseId`, reps, and weight from the pending item.
- set `setIndex` from 0 to `sets - 1`.
- set `completed: true`.
- save them with `AppDatabase.saveWorkoutSetLogs(userId, logs)`.

Do not send `WorkoutSetLog` to Supabase in this task.

### Program advance

Use completion-based advancement:

- Only consider advancing when there is an active program and its current day is
  a training day.
- Manual-only workouts must not advance the program.
- Rest days must not advance from the workout save flow.
- A partial planned workout must not advance the program.
- Advance only when the saved pending program-derived items cover every
  `ProgramExercise.id` in the active current day.
- Ignore extra manual pending items; they should not block or trigger advance.
- After advancing, refresh/invalidate the program providers so the next opened
  workout day shows the next program day.

Use the existing `TrainingProgramsNotifier.advanceDay()` if appropriate, or add
a similarly scoped method. Be careful not to read stale active program state.

### User feedback

Keep existing "Workout saved" feedback. If the program advanced, it is OK to
append short text such as "Program advanced" to the snackbar. Do not introduce a
large modal or new confirmation flow in this task.

## Tests

Add focused unit tests where practical. At minimum:

- `TrainingProgram.advanceToNextDay` behavior should remain covered.
- Add a small pure helper if that makes the "should advance" decision testable.
  Cover:
  - all planned exercise ids saved => advance
  - only manual entries => no advance
  - partial planned entries => no advance
  - rest day/no active day => no advance

Prefer pure unit tests over a large widget harness.

## Verification

Run:

```sh
/home/dyy/flutter/bin/flutter test test/features/training_program_test.dart
/home/dyy/flutter/bin/flutter test test/features/progression_test.dart
/home/dyy/flutter/bin/flutter test test/widget_test.dart
/home/dyy/flutter/bin/flutter analyze --no-fatal-infos --no-fatal-warnings
```

If a command fails, fix the code and rerun it.

## Non-goals

- Do not remove the old exercise-level progressive overload controls.
- Do not sync training programs or workout set logs to Supabase.
- Do not redesign the whole workout UI.
- Do not change auth, subscription, nutrition, or body tracking.
- Do not commit changes.

## Final Response

When done, summarize:

- files changed
- how pending program metadata is tracked
- when the program advances and when it does not
- tests run and results
- any remaining risks or follow-up work
