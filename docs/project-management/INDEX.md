# FitForge Project Management Index

last_verified_commit: `18cb461`
last_verified_date: `2026-07-15 UTC`
owner_skill: `/home/dyy/.codex/skills/fitforge-general-contractor/SKILL.md`
repo_path: `/home/dyy/fitforge`

This directory is FitForge's versioned project-management knowledge base. Live code, tests, git state, and command output remain authoritative.

## Document Inventory

- `ROADMAP.md`: planned 1-3 month direction and active epics.
- `BACKLOG.md`: prioritized feature, release, and technical-debt queue.
- `MODULE_MAP.md`: module responsibilities, boundaries, and size signals.
- `DECISION_LOG.md`: durable product and architecture decisions.
- `QUALITY_GATES.md`: local, CI, release, and deployment gates.
- `RISK_REGISTER.md`: active and mitigated product/engineering risks.
- `TRAINING_PROGRAM_SMOKE_CHECKLIST.md`: repeatable mobile training-program smoke checklist.
- `task-reports/`: consolidated reports for non-trivial tasks and delegated work.

## Current Task Reports

- `task-reports/2026-07-09-project-governance-bootstrap.md`
- `task-reports/2026-07-09-training-program-smoke-and-cycle-wording.md`
- `task-reports/2026-07-09-long-gap-backlog-audit.md`
- `task-reports/2026-07-09-long-gap-provider-regression-tests.md`
- `task-reports/2026-07-09-long-gap-widget-regression-tests.md`
- `task-reports/2026-07-10-mobile-smoke-readiness-and-cycle-wording-guard.md`
- `task-reports/2026-07-10-training-program-screen-split.md`
- `task-reports/2026-07-13-android-smoke-bootstrap.md`
- `task-reports/2026-07-13-training-program-storage-versioning.md`
- `task-reports/2026-07-13-p1-stabilization-and-sync-foundation.md`
- `task-reports/2026-07-15-real-device-smoke-retry.md`

## Source Of Truth Order

1. Live code, tests, git state, and command output.
2. Committed project-management docs with a matching `last_verified_commit`.
3. `HANDOFF.md` temporary conversation handoff.
4. Worker summaries and chat history.

## Current Local State

- Branch: `main`.
- Local `HEAD` and `origin/main`: `18cb461` (`Add long-gap recovery widget tests`).
- The current approved batch includes the P1 stabilization, training-sync
  foundation, and LAN mobile-smoke records. Training sync remains default-off
  and the database migration has not been deployed.
- The last checked Actions run and Pages deployment for `18cb461` were green;
  every approved push must be checked independently before reporting deployment.
- Training sync remains capability-gated with `FITFORGE_TRAINING_SYNC_V1=false` by default.
- `supabase/migrations/202607130001_training_sync_foundation.sql` exists locally but has not been applied to a real Supabase/PostgreSQL environment.
- The 2026-07-15 real-device retry recovered through LAN
  `192.168.31.56:5555`, installed the same-signed 23.3 MB release APK with data
  preserved, and completed a timeboxed TP-01 through TP-13 smoke. No product
  defect or crash was found in the executed paths; exhaustive manual subcases
  remain documented in the task report and checklist.
- Production Pro entitlement work remains explicitly deferred.
- `HANDOFF.md` remains an ignored temporary artifact.

## Update Rules

- Add a task report for non-trivial work.
- Update architecture decisions, risks, quality gates, module boundaries, and priorities in their matching documents.
- Never store credentials, pairing codes, raw environment dumps, or long-form model reasoning here.
