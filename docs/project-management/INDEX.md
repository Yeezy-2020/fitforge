# FitForge Project Management Index

last_verified_commit: `b8d3a28`
last_verified_date: `2026-07-09 UTC`
owner_skill: `/home/dyy/.codex/skills/fitforge-general-contractor/SKILL.md`
repo_path: `/home/dyy/fitforge`

This directory is the local server-side project management knowledge base for FitForge. Treat it as a versioned snapshot layer, not as the primary source of truth. Code, tests, git state, and command output remain authoritative.

## Document Inventory

- `INDEX.md`: entry point, document inventory, and verification metadata.
- `ROADMAP.md`: planned 1-3 month product direction and active epics.
- `BACKLOG.md`: feature, bug, and tech-debt queues.
- `MODULE_MAP.md`: module ownership, complexity, and boundaries.
- `DECISION_LOG.md`: durable product and architecture decisions.
- `QUALITY_GATES.md`: validation, review, release, and deployment gates.
- `RISK_REGISTER.md`: active risks, mitigations, and owners.
- `TRAINING_PROGRAM_SMOKE_CHECKLIST.md`: repeatable mobile manual smoke checklist for training-program flows.
- `task-reports/`: consolidated reports for non-trivial tasks and delegated worker outputs.

## Current Task Reports

- `task-reports/2026-07-09-project-governance-bootstrap.md`: initial project-management knowledge-base bootstrap and README drift cleanup.
- `task-reports/2026-07-09-training-program-smoke-and-cycle-wording.md`: training-program smoke checklist plus cycle-neutral progression model cleanup.
- `task-reports/2026-07-09-long-gap-backlog-audit.md`: long-gap recovery prompt implementation audit and backlog correction.
- `task-reports/2026-07-09-long-gap-provider-regression-tests.md`: provider-level long-gap recovery regression tests.
- `task-reports/2026-07-09-long-gap-widget-regression-tests.md`: widget/dialog regression tests for long-gap recovery UI.

## Source Of Truth Order

1. Live code, tests, git state, and command output.
2. Committed project-management docs with a matching `last_verified_commit`.
3. `HANDOFF.md` temporary conversation handoff.
4. Worker summaries and chat history.

When using any document here, verify whether relevant files changed after its `last_verified_commit`.

## Update Rules

- Ordinary non-trivial code task: add or update one task report under `task-reports/`.
- Architecture or product-direction change: update `DECISION_LOG.md`.
- New or changed risk: update `RISK_REGISTER.md`.
- Release, test, review, or deployment process change: update `QUALITY_GATES.md`.
- New module or large module reshaping: update `MODULE_MAP.md`.
- Roadmap or prioritization change: update `ROADMAP.md` or `BACKLOG.md`.

Do not store secrets, private credentials, one-time device codes, raw environment dumps, or long-form model reasoning in this directory.

## Current Local State

- Current branch was last observed as `main`, ahead of `origin/main` by 5 local commits before this task's commit.
- `HANDOFF.md` is ignored and treated as a temporary local handoff artifact.
- Latest local commit before this task: `b8d3a28` (`Add long-gap recovery provider tests`).
