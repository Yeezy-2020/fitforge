# Project Governance Bootstrap

last_verified_commit: `71b38dfc3f8b`
task_status: `completed-local`
owner: `main Codex general contractor`
created_at: `2026-07-09 UTC`
updated_at: `2026-07-09 UTC`

## Summary

Established the FitForge project-management knowledge base and initial governance documents. Updated the FitForge skill with a governance bootstrap rule before writing docs. README was minimally corrected where it had drifted from current repository facts.

## Files Changed

- `.gitignore`
- `scripts/pre_push.sh`
- `/home/dyy/.codex/skills/fitforge-general-contractor/SKILL.md`
- `README.md`
- `docs/project-management/INDEX.md`
- `docs/project-management/task-reports/README.md`
- `docs/project-management/DECISION_LOG.md`
- `docs/project-management/MODULE_MAP.md`
- `docs/project-management/RISK_REGISTER.md`
- `docs/project-management/QUALITY_GATES.md`
- `docs/project-management/BACKLOG.md`
- `docs/project-management/ROADMAP.md`
- `docs/project-management/task-reports/2026-07-09-project-governance-bootstrap.md`

## Verification

- Skill validation passed with `python3 /home/dyy/.codex/skills/.system/skill-creator/scripts/quick_validate.py /home/dyy/.codex/skills/fitforge-general-contractor`.
- `flutter analyze --no-fatal-infos --no-fatal-warnings` passed with the known info-level baseline.
- Independent governance review ran with `codex exec -m gpt-5.5 -c model_reasoning_effort="high" -s read-only`.
- `bash scripts/pre_push.sh` passed after rerunning outside the network-restricted sandbox: analyze, full test, widget dump, and dead-button scan all passed.
- Full Flutter tests were run through `scripts/pre_push.sh`.

## Agent Report: module-map worker

- Task: Draft `MODULE_MAP.md`.
- Scope: Read-only repo inspection at HEAD `71b38dfc3f8b`.
- Files inspected: `README.md`, `docs/project-management/INDEX.md`, `lib/main.dart`, `lib/app.dart`, `lib/providers/*`, `lib/data/repositories/*`, `lib/data/models/training_program.dart`, `lib/core/services/*`, `lib/core/utils/*`, `lib/features/**`, `test/**`.
- Files changed: None.
- Key findings: Code is layered by app/core/data/providers/features; Workout and Nutrition are complex cores; provider/database/screen responsibilities are concentrated.
- Decisions / assumptions: Complexity assessed by line count, responsibility count, cross-layer dependencies, and test concentration.
- Tests run: None; static inspection only.
- Risks: README test count was stale; module map must be verified before future use.
- Follow-ups: Split training-program UI, providers, and AppDatabase; define training-program remote sync strategy.
- Evidence: `lib` about 14.6k lines, tests about 3.6k lines, total about 18.3k Dart lines; large files include `program_detail_screen.dart`, `workout_day_screen.dart`, `training_program.dart`, and `app_database.dart`.

## Agent Report: risk worker

- Task: Draft `RISK_REGISTER.md`.
- Scope: Read-only repo inspection at HEAD `71b38dfc3f8b`.
- Files inspected: `README.md`, `HANDOFF.md`, `.github/workflows/deploy.yml`, `lib/data/repositories/app_database.dart`, `lib/core/services/sync_service.dart`, `lib/core/services/supabase_service.dart`, `lib/providers/app_providers.dart`, `lib/data/models/training_program.dart`, `lib/features/workout/screens/workout_day_screen.dart`, `lib/features/subscription/screens/paywall_screen.dart`, `lib/core/localization/l10n.dart`, `test/features/training_program_test.dart`, `test/features/progression_test.dart`.
- Files changed: None.
- Key findings: Highest risks are local-only training-plan/set-log context, local Pro unlock, and inconsistent i18n/user-isolation coverage.
- Decisions / assumptions: Owners are suggested responsibility domains; likelihood uses high/medium/low.
- Tests run: None; read-only inspection.
- Risks: See `RISK_REGISTER.md`.
- Follow-ups: Design Supabase plan/set-log schema, production entitlement verification, user-isolation audit, and CI expansion.
- Evidence: Storage and sync paths in `app_database.dart`, `sync_service.dart`, and `supabase_service.dart`; local Pro behavior in `paywall_screen.dart`.

## Agent Report: quality-gates worker

- Task: Draft `QUALITY_GATES.md`.
- Scope: Read-only repo inspection at HEAD `71b38dfc3f8b`.
- Files inspected: `README.md`, `scripts/pre_push.sh`, `.github/workflows/deploy.yml`, `test/`, `analysis_options.yaml`, `pubspec.yaml`, `pubspec.lock`.
- Files changed: None.
- Key findings: Local pre-push gate is stronger than CI; deploy workflow runs tests and Web build but not analyze/dead-button scan.
- Decisions / assumptions: Web build remains internal preview/deployment check, not formal platform support.
- Tests run: None by worker.
- Risks: README and CI behavior can drift; stable Flutter channel can change analyzer output.
- Follow-ups: Add analyze/dead-button checks to CI and document any stable-channel drift.
- Evidence: `scripts/pre_push.sh` runs analyze/test/widget dump/dead-button scan; `.github/workflows/deploy.yml` runs pub get/test/web build/deploy.

## Agent Report: roadmap-backlog worker

- Task: Draft `BACKLOG.md` and `ROADMAP.md`.
- Scope: Read-only repo inspection; no file writes.
- Files inspected: `README.md`, `HANDOFF.md`, `docs/project-management/INDEX.md`, `docs/project-management/task-reports/README.md`, `lib/`, `test/`, recent git log.
- Files changed: None.
- Key findings: Recent commits cluster around training-plan scheduling, cycles, pause, and deload; local main is ahead of origin by one commit.
- Decisions / assumptions: Live code/git/index outrank stale handoff content.
- Tests run: None.
- Risks: Unpushed local commit, real subscription/OAuth still incomplete, training-plan complexity increasing.
- Follow-ups: Archive backlog/roadmap, add smoke checklist, update risk and quality docs.
- Evidence: Latest local commit `71b38df Refine training program scheduling and deloads`; README still marks Google/Apple login TODO and development-stage purchase verification.

## Notes

README audit could not be delegated with `spawn_agent` because the agent thread limit was reached after the four core governance workers. The main Codex used local evidence, the quality-gates worker findings, and a later `codex exec` read-only governance review for minimal README corrections.

The skill file is outside the FitForge git repository. It is listed here as external local configuration, not as a repo file that will be committed.

## Agent Report: governance-review worker

- Task: Read-only review of the governance documentation diff.
- Scope: README, project-management docs, task reports, `HANDOFF.md`, CI/script drift, secret-like strings, and git state.
- Files inspected: `README.md`, `HANDOFF.md`, `.gitignore`, `.github/workflows/deploy.yml`, `scripts/pre_push.sh`, `pubspec.yaml`, `lib/core/constants/app_constants.dart`, all files under `docs/project-management/`.
- Files changed: None.
- Key findings: README contained reusable test credentials; `HANDOFF.md` was stale and not ignored; `scripts/pre_push.sh` assumed `/opt/flutter`; `DECISION_LOG.md` was referenced but missing; README lacked a governance-doc entry; the task report needed to label the skill file as external local config.
- Decisions / assumptions: Supabase URL and anon key are not treated as service-role secrets; reusable test passwords should not be stored in repo docs; `HANDOFF.md` should remain excluded.
- Tests run: No Flutter tests or analyzer by reviewer; read-only `git`, `rg`, `find`, `nl`, `wc`, and `git diff --check`.
- Risks: Future agents could trust stale handoff state or fail local gates if Flutter path resolution is wrong.
- Follow-ups: Keep test credentials out of repo docs; keep `HANDOFF.md` ignored; close CI gaps listed in `QUALITY_GATES.md`.
- Evidence: Current branch was `main` ahead of `origin/main` by 1; static test declaration count was 209; CI workflow runs `flutter pub get`, `flutter test`, and Web build; `git diff --check` had no whitespace errors.
