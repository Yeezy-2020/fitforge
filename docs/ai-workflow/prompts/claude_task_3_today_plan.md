# Claude Task 3: Today's Program Workout Suggestions

You are working in `/home/dyy/fitforge`, a Flutter/Riverpod fitness app.

## Goal

Add the third MVP slice for training-program-based progressive overload:
when a user opens a workout day, show suggestions from the active training
program's current day and let the user add those suggested exercises to the
pending workout list.

Do not advance the program after saving yet. Do not change workout persistence
behavior in this task.

## Existing Context

- Training program models are in `lib/data/models/training_program.dart`.
- Program storage/provider exists in `lib/data/repositories/app_database.dart`
  and `lib/providers/app_providers.dart`.
- Program UI exists in:
  - `lib/features/workout/screens/training_programs_screen.dart`
  - `lib/features/workout/screens/program_detail_screen.dart`
- Workout entry screen:
  - `lib/features/workout/screens/workout_day_screen.dart`
- Existing exercise-level progression:
  - `lib/core/utils/progression_calculator.dart`
  - `progressionSuggestionProvider`
- Existing workout logs are aggregate `WorkoutLog`s.

## Required Behavior

When `WorkoutDayScreen` opens:

- If no active program exists, keep the current manual exercise flow unchanged.
- If the active program's current day is a rest day:
  - show a compact "Rest day" panel near the top.
  - still allow manual logging below.
- If the active program's current day is a training day:
  - show a compact "Today's program" panel near the top.
  - list the program day's exercises in order.
  - show suggested sets, reps, and weight for each exercise.
  - provide per-exercise "Add" action.
  - provide "Add all" action.
  - adding suggestions should append to `_pendingSets` using the existing
    `_addToPending` flow.

Manual edits and the existing exercise cards must continue to work. Do not
replace the existing search/body-part exercise picker.

## Suggestion Rules

Add a small calculation helper if useful. Use `WorkoutPrescription` as the
result model.

For each `ProgramExercise`:

- If there is no previous workout log for that exercise before the selected
  date:
  - sets = `targetSets`
  - reps = `minReps`
  - weightKg = `startingWeightKg`
  - reason = "Start from program"
- For `doubleProgression`:
  - if last reps are below `maxReps`, keep weight and add 1 rep.
  - if last reps reached `maxReps`, add `weightIncrementKg` and reset reps to
    `minReps`.
- For `linearWeight`:
  - keep the last reps clamped into the configured range.
  - add `weightIncrementKg` to the last weight.
- For `periodized`:
  - keep this MVP conservative: use starting values if no log, otherwise keep
    last sets/reps/weight. Do not build a calendar-cycle engine in this task.

Clamp invalid outputs:

- sets at least 1
- reps at least 1
- weight at least 0

## Providers

Add provider(s) in `lib/providers/app_providers.dart`, for example:

- `workoutPrescriptionsForDateProvider`

The provider must:

- watch `currentUserIdProvider`
- watch `activeTrainingProgramProvider`
- use local `AppDatabase.getLastWorkoutLogForExercise`
- return empty list for no active program, empty program, or rest day
- not connect Supabase

If you need rest-day information in UI, expose it without additional storage.

## Tests

Add focused unit tests for the new prescription calculation, preferably in:

`test/features/training_program_test.dart`

Cover:

- no last log uses program starting values
- double progression adds reps below max
- double progression adds weight and resets reps at max
- linear progression adds weight
- periodized keeps last values for MVP

Widget tests are optional. Do not spend time building a large widget harness.

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

- Do not advance `currentDayIndex` after saving.
- Do not save `WorkoutSetLog` yet.
- Do not remove the old exercise-level progressive overload controls.
- Do not connect Supabase.
- Do not change auth, sync, subscription, or diet behavior.

## Final Response

When done, summarize:

- files changed
- provider/calculation approach
- UI behavior on training day/rest day/no program
- tests run and results
- any remaining risks or follow-up work
