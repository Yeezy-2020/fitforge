# Training Program Smoke And Cycle Wording

last_verified_commit: `800a1f1`
last_verified_date: `2026-07-09 UTC`

## Summary

Created the training-program manual smoke checklist and removed the remaining active model/test `periodWeeks` naming from `ProgressionScheme`. Old saved JSON using `periodWeeks` remains readable; new JSON writes `periodCycles`.

## Agent Report: cycle-wording auditor

- Task: Audit training-program week/cycle wording and identify cleanup targets.
- Scope: Read-only search across training-program UI, localization, docs, tests, and model code.
- Files inspected: `lib/core/localization/l10n.dart`, `lib/data/models/training_program.dart`, `lib/core/utils/program_prescription_calculator.dart`, `test/features/training_program_test.dart`, project-management docs.
- Files changed: None by worker.
- Key findings: User-facing training-program copy already uses cycle/round language. `ProgressionScheme.periodWeeks` and tests were the remaining meaningful natural-week model residue.
- Decisions / assumptions: Rename the field to `periodCycles`; keep `periodWeeks` as a legacy JSON input only.
- Tests run: None; read-only audit.
- Risks: Any old code outside the searched repo expecting new writes to include `periodWeeks` would no longer see that key.
- Follow-ups: Keep future progression copy/model additions cycle-neutral unless the behavior truly uses calendar weeks.
- Evidence: `rg periodWeeks` showed only `lib/data/models/training_program.dart` and `test/features/training_program_test.dart` before cleanup.

## Agent Report: smoke-checklist drafter

- Task: Draft a mobile manual smoke checklist for training-program stabilization.
- Scope: Read-only inspection and checklist draft.
- Files inspected: `README.md`, `docs/project-management/BACKLOG.md`, `ROADMAP.md`, `QUALITY_GATES.md`, `lib/features/workout/screens/*`, `lib/data/models/training_program.dart`, `lib/providers/app_providers.dart`, `test/features/training_program_test.dart`.
- Files changed: None by worker.
- Key findings: Existing code supports create/edit/reorder, deloads, finite/continuous cycles, future scheduling, pause/resume/end, active selection by date, workout prescriptions, auto-advance, rest-day completion, long-break prompt, localization, and kg/lb workout display.
- Decisions / assumptions: Checklist is mobile-first; Web preview is not treated as a supported platform. Long-break readiness may require seeded local data or date manipulation.
- Tests run: None; read-only checklist task.
- Risks: Manual date flows are sensitive to current date/time. Some program configuration labels remain kg-oriented and should be recorded as unit gaps when encountered.
- Follow-ups: Execute `TRAINING_PROGRAM_SMOKE_CHECKLIST.md` on mobile/emulator and file failures.
- Evidence: Static inspection of model/provider/screen flows plus existing `training_program_test.dart` coverage.

## Main Integration

- Added `docs/project-management/TRAINING_PROGRAM_SMOKE_CHECKLIST.md`.
- Updated `INDEX.md`, `BACKLOG.md`, `ROADMAP.md`, and `DECISION_LOG.md`.
- Updated `ProgressionScheme` from `periodWeeks` to `periodCycles`, with legacy `periodWeeks` JSON fallback.
- Updated focused model and storage-path tests for the new field and legacy compatibility.
- Updated the stale AI workflow prompt that still listed `periodWeeks`.

## Agent Report: reviewer

- Task: Review uncommitted diff for `periodWeeks` to `periodCycles`, legacy JSON compatibility, new JSON writes, and project-management docs.
- Scope: Read-only review of tracked changes plus untracked project-management docs.
- Files inspected: `lib/data/models/training_program.dart`, `test/features/training_program_test.dart`, `lib/data/repositories/app_database.dart`, `docs/project-management/*`, `docs/project-management/task-reports/2026-07-09-training-program-smoke-and-cycle-wording.md`, `docs/ai-workflow/prompts/claude_task_1_domain_storage.md`.
- Files changed: None by reviewer.
- Key findings: No blocking code issues. The stale AI workflow prompt still named `periodWeeks`; new referenced docs had to be explicitly added; full persisted TrainingProgram JSON needed a legacy fixture test.
- Decisions / assumptions: `periodWeeks` remains only a legacy JSON input and explanatory reference.
- Tests run: `git diff --check`.
- Risks: Future agents could follow stale prompts if workflow docs drift again.
- Follow-ups: Execute the mobile smoke checklist and keep future progression naming cycle-neutral.
- Evidence: Reviewer `rg periodWeeks .` found the stale workflow prompt plus intended compatibility references.

## Verification

- Dart format passed for `lib/data/models/training_program.dart` and `test/features/training_program_test.dart`.
- `flutter test test/features/training_program_test.dart` passed.
- `flutter analyze --no-fatal-infos --no-fatal-warnings` passed with the known info-level baseline.
- `git diff --check` passed.
- `bash scripts/pre_push.sh` passed: analyze, full tests, widget dump, and dead-button scan all passed.
- Independent read-only `gpt-5.5/high` review found no blocking issues; follow-up findings were handled in this task.
