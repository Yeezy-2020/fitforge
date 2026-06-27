# GPT Review Task 4: Workout Completion and Program Advance

You are reviewing uncommitted changes in `/home/dyy/fitforge`.

## Review Goal

Review Task 4 of the training program MVP: saving program-derived workout
suggestions should persist local `WorkoutSetLog`s and advance the active program
only when the active current training day is fully completed.

## Expected Behavior

- Pending workout items can carry optional program metadata:
  - `programId`
  - `programDayId`
  - `programExerciseId`
- Manual/custom/template/old progression additions must keep program metadata
  null.
- Planned suggestion "Add" and "Add all" must preserve metadata from
  `WorkoutPrescription`.
- `_saveAll()` must still save normal `WorkoutLog`s exactly as before.
- For program-derived pending items, `_saveAll()` must save local
  `WorkoutSetLog` records:
  - one per set
  - linked to the saved `WorkoutLog.id`
  - with `completed: true`
  - no Supabase write for set logs
- Program advancement must be completion-based:
  - no active program => no advance
  - rest day => no advance from save flow
  - manual-only workout => no advance
  - partial planned workout => no advance
  - saved planned items cover every exercise id in the active current day =>
    advance exactly once
- Provider state should refresh after advance.
- No unrelated auth/nutrition/subscription/sync changes.

## What To Check

1. Correctness and regressions in `workout_day_screen.dart`.
2. Riverpod state correctness: no stale user/program state; active program is
   read at the right time.
3. Data integrity in `WorkoutSetLog` generation and storage.
4. Whether manual flows accidentally advance the program.
5. Whether partial plan completion accidentally advances the program.
6. Tests for the advance decision or equivalent logic.
7. Analyze/build risks.

## Output Format

Return:

1. Findings ordered by severity with file/line references.
2. Open questions or assumptions.
3. Test gaps or commands that still need to run.
4. Overall verdict: accept, accept with follow-ups, or reject.
