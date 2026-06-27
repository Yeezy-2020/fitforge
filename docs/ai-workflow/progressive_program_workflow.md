# Progressive Program AI Workflow

This workflow keeps the training program redesign split into small, reviewable
tasks. The owner role is product and architecture. Claude writes large code
changes. Codex/GPT reviews the uncommitted diff before the owner decides the
next prompt.

## Roles

- Owner: define product behavior, architecture boundaries, task prompts, and
  final accept/reject decisions.
- Claude: implement one scoped task at a time in the local repository.
- Codex/GPT reviewer: review the uncommitted diff for correctness, regressions,
  state management issues, and missing tests.

## Task Sequence

1. Domain skeleton and local storage.
2. Program management UI.
3. Today's planned workout generation.
4. Workout completion and next recommendation updates.
5. Tests, README, and cleanup of old exercise-level entry points.

## Global Constraints

- Keep Supabase out of the MVP unless a task explicitly says otherwise.
- Store data locally using existing `AppDatabase` patterns.
- New user-scoped providers must depend on `ref.watch(currentUserIdProvider)`.
- Do not refactor unrelated nutrition, auth, subscription, or sync behavior.
- Preserve existing workout logs and the current progression calculator unless
  a task explicitly asks to migrate them.
- Manual workout input must remain higher priority than async suggestions in
  later UI tasks.
- Prefer completion-based plan progression over calendar-only progression.

## Verification Baseline

After each task, run the narrowest useful tests plus:

```sh
/home/dyy/flutter/bin/flutter test test/features/progression_test.dart
/home/dyy/flutter/bin/flutter analyze --no-fatal-infos --no-fatal-warnings
```

If a task adds new tests, run those directly as well.
