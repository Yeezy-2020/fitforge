# Training Program Screen Split

last_verified_commit: `18cb461`
task_status: `complete`
owner: `fitforge-general-contractor`
created_at: `2026-07-10 UTC`
updated_at: `2026-07-10 UTC`

## Summary

Split the two largest training-program screen files into focused Dart part files without changing behavior or public APIs. Added a real-provider widget smoke test for the program-detail screen so future structural work has a focused rendering and dialog-entry regression check.

## Agent Report: architecture worker

- Task: Define low-risk boundaries for splitting `program_detail_screen.dart` and `workout_day_screen.dart`.
- Scope: Read-only source and dependency inspection.
- Files inspected: Both screen roots, their models/providers/helpers, and adjacent tests.
- Files changed: None.
- Key findings: Dart `part` files preserve library-private types and minimize state/callback rewiring. The safest first step is a mechanical move of cohesive UI blocks, leaving domain behavior and state ownership in the roots.
- Decisions / assumptions: Preserve all imports, identifiers, keys, lifecycle guards, controller disposal, and post-frame behavior exactly.
- Tests run: None; this was an architecture task.
- Risks: Part files reduce file size but do not by themselves create domain boundaries.
- Follow-ups: Extract domain rules only in separately tested changes.

## Agent Report: test-inventory worker

- Task: Identify existing coverage and add the smallest missing regression test.
- Scope: Test inventory plus one widget smoke test.
- Files inspected: Screen tests, training-program tests, database/provider setup, and both target screens.
- Files changed: `test/screens/program_detail_screen_test.dart`.
- Key findings: Workout-day recovery behavior already has focused widget coverage, while program detail had no direct screen smoke.
- Decisions / assumptions: Seed the real local database/provider path, render one program/day/exercise, verify prescription summary and add-exercise entry, then open and cancel the edit-day dialog.
- Tests run: Focused widget test passed before and after the split.
- Risks: The smoke test does not open every deload or exercise-configuration dialog.
- Follow-ups: Add dialog-specific tests when those workflows change behavior.

## Agent Report: program-detail implementation worker

- Task: Mechanically split the program-detail screen.
- Scope: Move cohesive private declarations into part files; no behavior edits.
- Files changed: `program_detail_screen.dart`, `program_detail_deload_dialog.dart`, `program_detail_overview_widgets.dart`, and `program_detail_exercise_dialogs.dart`.
- Key findings: The 2019-line root becomes a 745-line coordinator; moved declarations retain library-private access through `part of`.
- Decisions / assumptions: Keep `ProgramDetailScreen`, ID generation, provider orchestration, and mutation flows in the root.
- Tests run: Dart format, targeted analyze, and mechanical diff checks passed.
- Risks: The full screen family remains large and still contains domain-adjacent orchestration.
- Follow-ups: Introduce explicit widget inputs/callbacks before moving true domain rules.

## Agent Report: workout-day implementation worker

- Task: Mechanically split the workout-day screen.
- Scope: Move the exercise card and progression sheet into part files; no behavior edits.
- Files changed: `workout_day_screen.dart`, `workout_day_exercise_card.dart`, and `workout_day_progression_sheet.dart`.
- Key findings: The 1529-line root becomes a 1039-line coordinator. Exercise-card state, post-frame suggestion handling, and progression-sheet public API remain unchanged.
- Decisions / assumptions: Keep pending-set state, program panel construction, and shared program localization keys in the root.
- Tests run: Dart format and mechanical diff checks passed.
- Risks: The root remains a hot spot and should be reduced through separately reviewed behavior-preserving extractions.
- Follow-ups: Isolate program-panel orchestration and persistence/domain operations incrementally.

## Agent Report: independent reviewer

- Task: Review the combined split for regressions, API drift, localization-guard gaps, and test adequacy.
- Scope: Read-only independent review of production and test diffs.
- Files changed: None.
- Key findings: No P0/P1 findings. Moved blocks match the original implementations apart from file boundaries and trailing newlines; public/private APIs, widget keys, lifecycle behavior, and shared workout-day localization coverage are preserved.
- Decisions / assumptions: The limited dialog coverage is acceptable for this mechanical refactor because existing behavior is unchanged and focused/domain tests remain in the gate.
- Tests run: None; review was intentionally read-only.
- Risks: Dialog runtime paths are only indirectly covered.
- Follow-ups: Keep future dialog behavior changes paired with targeted widget tests.

## Main Integration

- Added the required `part` directives and kept all imports in the library roots.
- Kept screen roots responsible for provider state and mutations while grouping private presentation declarations by responsibility.
- Added the program-detail widget smoke and retained workout-day recovery coverage.
- Updated the module map and backlog so the completed structural split is not confused with the remaining domain-extraction work.

## Verification

- Focused suite passed: wording guard, program-detail widget smoke, workout-day recovery widgets, and training-program unit tests (109 tests).
- Flutter analyze passed with only the existing 10 info-level baseline issues and no new warning or error.
- `bash scripts/pre_push.sh` passed analyze, the full Flutter test suite, widget dump, and the zero-dead-button check.
- Independent review found no P0/P1 issue in the combined split.

## Remaining Risk

- Mobile manual smoke remains paused until wireless debugging is configured.
- The part-file split improves navigability but does not yet move scheduling, persistence, or progression rules out of screen orchestration.
