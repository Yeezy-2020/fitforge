# Claude Task 1: Training Program Domain Skeleton and Local Storage

You are working in `/home/dyy/fitforge`, a Flutter/Riverpod fitness app.

## Goal

Implement the first MVP slice for a training-program-based progressive overload
system. This task is intentionally limited to domain models, local storage,
providers, and focused tests. Do not build UI yet.

## Existing Context

- Current branch should be `ai/program-mvp-task1`.
- Existing progression feature files:
  - `lib/data/models/progression_rule.dart`
  - `lib/core/utils/progression_calculator.dart`
  - `test/features/progression_test.dart`
- Local storage is centralized in:
  - `lib/data/repositories/app_database.dart`
- App-wide Riverpod providers are in:
  - `lib/providers/app_providers.dart`
- Existing user identity provider:
  - `currentUserIdProvider`
- Existing workout logs are aggregate logs in:
  - `lib/data/models/workout_log.dart`

## Required Models

Add a new model file, preferably:

`lib/data/models/training_program.dart`

Define immutable classes with `fromJson`, `toJson`, and useful `copyWith`
methods:

- `TrainingProgram`
  - `id`
  - `userId`
  - `name`
  - `days`
  - `active`
  - `currentDayIndex`
  - `advanceMode`
  - `createdAt`
  - `updatedAt`
- `ProgramDay`
  - `id`
  - `name`
  - `kind` (`training` or `rest`)
  - `exercises`
- `ProgramExercise`
  - `id`
  - `exerciseId`
  - `targetSets`
  - `minReps`
  - `maxReps`
  - `startingWeightKg`
  - `progressionScheme`
  - `sortOrder`
- `ProgressionScheme`
  - `type` supporting at least `doubleProgression`, `linearWeight`,
    `fixedLoad`, `linearPeriodization`
  - `weightIncrementKg`
  - `percentIncrement`
  - `periodCycles`
  - `deloadPercent`
- `WorkoutPrescription`
  - `programId`
  - `programDayId`
  - `programExerciseId`
  - `exerciseId`
  - `sets`
  - `reps`
  - `weightKg`
  - `reason`
- `WorkoutSetLog`
  - `id`
  - `workoutLogId`
  - `programId`
  - `programExerciseId`
  - `setIndex`
  - `reps`
  - `weightKg`
  - `completed`

Use enum parsing helpers that tolerate unknown or missing strings by falling
back to sensible defaults. JSON must be backward-compatible in the sense that
missing optional fields do not crash.

## Local Storage

Extend `AppDatabase` with user-scoped methods:

- `getTrainingPrograms(String userId)`
- `saveTrainingPrograms(String userId, List<TrainingProgram> programs)`
- `saveTrainingProgram(String userId, TrainingProgram program)`
- `deleteTrainingProgram(String userId, String programId)`
- `getActiveTrainingProgram(String userId)`
- `setActiveTrainingProgram(String userId, String programId)`
- `saveWorkoutSetLogs(String userId, List<WorkoutSetLog> logs)`
- `getWorkoutSetLogs(String userId, String workoutLogId)`

Use secure-storage keys under the existing `_key(userId, type)` helper. Do not
connect Supabase.

## Providers

Add providers in `lib/providers/app_providers.dart`:

- `trainingProgramsProvider`
- `activeTrainingProgramProvider`

Use `AsyncNotifier` or existing local patterns. In the `build` method, depend
on `ref.watch(currentUserIdProvider)`, not `ref.read`, so switching users does
not show stale programs.

Expose notifier methods sufficient for future UI tasks:

- save/upsert a program
- delete a program
- set active program
- advance current day by completion

Keep these providers local-storage only.

## Tests

Add focused tests, preferably:

`test/features/training_program_test.dart`

Cover:

- JSON roundtrip for `TrainingProgram` with a training day, rest day, exercise,
  and progression scheme.
- Missing enum/type strings use safe defaults.
- `copyWith` can update `currentDayIndex` and active state.
- A simple helper or model behavior supports a "train 3, rest 1" cycle without
  losing rest days.

Do not write widget tests in this task.

## Non-goals

- No UI screens.
- No routing changes.
- No Supabase schema or sync.
- Do not delete the existing exercise-level `ProgressionRule` feature.
- Do not rewrite `WorkoutLog` into set-level logs yet; only add
  `WorkoutSetLog` as a future-compatible model and local storage.
- Do not broad-format unrelated files.

## Verification

Run:

```sh
/home/dyy/flutter/bin/flutter test test/features/training_program_test.dart
/home/dyy/flutter/bin/flutter test test/features/progression_test.dart
/home/dyy/flutter/bin/flutter analyze --no-fatal-infos --no-fatal-warnings
```

If a command fails, fix the code and rerun it.

## Final Response

When done, summarize:

- files changed
- model/provider/storage decisions
- tests run and results
- any remaining risks or follow-up work
