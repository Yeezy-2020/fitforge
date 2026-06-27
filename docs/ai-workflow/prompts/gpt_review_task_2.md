# GPT Review Task 2: Training Program Management UI

Review the uncommitted diff for the FitForge Flutter/Riverpod repository.

## Review Stance

Prioritize bugs, regressions, state-management mistakes, and UI behavior that
will block the next task. Findings should be concrete, with file and line
references where possible.

## What Changed

The implementation should add a local training program management UI:

- route under `/home`, such as `/home/programs`
- entry point from the training calendar screen
- program list and active program marker
- create starter "3 on / 1 off" program
- edit program name
- add/edit/delete training and rest days
- add/remove exercises on training days
- configure sets, rep range, starting weight, progression type, and increment
- set active program and delete program

## Must Check

- Program writes go through `trainingProgramsProvider.notifier`, not direct
  `AppDatabase` calls from the UI.
- The UI does not connect Supabase or alter sync/auth/subscription behavior.
- The route is reachable without breaking existing `/home/day/:date`.
- The training calendar's existing log workout button still works.
- The screen handles empty programs, rest days, and no exercises without
  crashing.
- Only one active program can be produced from the UI path.
- Exercise names render from `exerciseListProvider` and tolerate missing IDs.
- Numeric inputs are validated enough to avoid invalid sets/reps/weights.
- The UI does not change `WorkoutDayScreen` save behavior yet.
- Existing progression model/tests are not broken.

## Output Format

Return:

1. Findings, ordered by severity.
2. Open questions or assumptions.
3. Test gaps or commands that still need to run.
4. Short overall verdict: accept, accept with follow-ups, or reject.
