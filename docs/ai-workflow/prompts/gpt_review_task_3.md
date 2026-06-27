# GPT Review Task 3: Today's Program Workout Suggestions

Review the uncommitted diff for the FitForge Flutter/Riverpod repository.

## Review Stance

Prioritize bugs, regressions, state-management mistakes, and behavior that
would block using active programs from the workout screen.

## What Changed

The implementation should add active-program workout suggestions:

- prescription calculator/helper
- provider for workout prescriptions by date
- workout day UI panel for active program training/rest days
- per-exercise add and add-all actions into existing pending workout flow
- focused calculator tests

## Must Check

- No Supabase connection for program prescriptions.
- Provider watches `currentUserIdProvider` and active program state.
- No-program path keeps the existing manual workout flow unchanged.
- Rest day shows rest state but still allows manual logging.
- Training day suggestions preserve exercise order and tolerate missing exercise
  metadata.
- Add/add-all uses the existing pending-set flow and does not save immediately.
- Existing exercise-level progression UI remains usable.
- Workout save behavior and program advancement are not changed in this task.
- Suggestion math handles no prior log, double progression, linear progression,
  periodized MVP behavior, and clamps invalid values.
- Tests cover the calculator logic.

## Output Format

Return:

1. Findings, ordered by severity.
2. Open questions or assumptions.
3. Test gaps or commands that still need to run.
4. Short overall verdict: accept, accept with follow-ups, or reject.
