# Claude Task 2: Training Program Management UI

You are working in `/home/dyy/fitforge`, a Flutter/Riverpod fitness app.

## Goal

Build the second MVP slice for training-program-based progressive overload:
a usable local training program management screen. This task is UI and provider
integration only. Do not generate today's workout and do not change workout
logging behavior yet.

## Existing Context

- Current branch should be `ai/program-mvp-task1`.
- Task 1 added:
  - `lib/data/models/training_program.dart`
  - training program storage methods in `lib/data/repositories/app_database.dart`
  - `trainingProgramsProvider` and `activeTrainingProgramProvider` in
    `lib/providers/app_providers.dart`
  - `test/features/training_program_test.dart`
- Existing routing is in `lib/app.dart`.
- Existing training home is `lib/features/workout/screens/workout_calendar_screen.dart`.
- Exercise data is available through `exerciseListProvider`.
- Localization exists, but many current workout strings are already literal
  English. You may use concise literal UI strings for this MVP.

## Required UX

Add a training program management screen, preferably:

`lib/features/workout/screens/training_programs_screen.dart`

The screen must let a user:

- See all local training programs.
- See which program is active.
- Create a starter "3 on / 1 off" program.
- Edit a program name.
- Add, edit, and delete training days and rest days.
- Add and remove exercises on a training day.
- For each program exercise configure:
  - target sets
  - min reps
  - max reps
  - starting weight kg
  - progression type: double progression, linear weight, periodized
  - weight increment kg
- Set one program active.
- Delete a program.

Add an entry point from the training calendar screen. Keep it small and obvious,
for example an icon button in the training calendar app bar. Do not replace the
existing log workout button.

Add a route under `/home`, for example:

`/home/programs`

## Design Constraints

- Keep UI utilitarian and dense enough for repeated training-plan editing.
- Do not create a landing page or explanatory marketing screen.
- Do not use nested cards.
- Do not use decorative gradients/orbs.
- Use stable control sizes and avoid text overflow.
- Prefer Material built-in icons and controls.
- It must work on narrow mobile screens.

## Implementation Constraints

- Use existing Riverpod providers, especially `trainingProgramsProvider`,
  `activeTrainingProgramProvider`, and `exerciseListProvider`.
- Program writes must go through `trainingProgramsProvider.notifier`, not
  direct storage calls from the screen.
- Do not connect Supabase.
- Do not change `WorkoutDayScreen` save behavior.
- Do not remove the existing exercise-level progression rule sheet yet.
- Keep edits scoped to routing, the training calendar entry point, the new
  screen, and any small provider/model helper necessary for the UI.
- Preserve user-scoped behavior; do not use raw Supabase auth in this screen.

## Starter Program

The starter "3 on / 1 off" program should create:

- Day 1: Push
- Day 2: Pull
- Day 3: Legs
- Day 4: Rest

Include a few sensible default exercises from the existing exercise IDs:

- Push: `ex_bench_press`, `ex_shoulder_press`, `ex_tricep_pushdown`
- Pull: `ex_pullup`, `ex_barbell_row`, `ex_bicep_curl`
- Legs: `ex_squat`, `ex_romanian_deadlift`, `ex_legpress`

Use target sets 3, min reps 8, max reps 12, starting weight 0, double
progression, 2.5 kg increment unless a better existing default is obvious.

## Tests

Add or update focused widget tests only if practical within this task. At a
minimum, existing model/progression tests must still pass. If widget tests are
too costly because of app setup, explain that in the final response.

## Verification

Run:

```sh
/home/dyy/flutter/bin/flutter test test/features/training_program_test.dart
/home/dyy/flutter/bin/flutter test test/features/progression_test.dart
/home/dyy/flutter/bin/flutter analyze --no-fatal-infos --no-fatal-warnings
```

If you add widget tests, run those too.

## Final Response

When done, summarize:

- files changed
- route/entry point added
- how the management screen works
- tests run and results
- any remaining risks or follow-up work
