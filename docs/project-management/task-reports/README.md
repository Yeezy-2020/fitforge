# FitForge Task Reports

Use this directory for consolidated reports from non-trivial FitForge tasks. The main Codex agent owns the final report and should merge, verify, and deduplicate worker output before archiving it here.

## Naming

Use:

```text
YYYY-MM-DD-short-task-slug.md
```

Example:

```text
2026-07-09-training-deload-scheduling.md
```

## Required Metadata

Each report should include:

```md
last_verified_commit:
task_status:
owner:
created_at:
updated_at:
```

## Agent Report Template

Each delegated worker or reviewer should return a section in this shape:

```md
## Agent Report: <role>

- Task:
- Scope:
- Files inspected:
- Files changed:
- Key findings:
- Decisions / assumptions:
- Tests run:
- Risks:
- Follow-ups:
- Evidence:
```

Archive conclusions, evidence, risks, tests, and follow-ups. Do not archive raw long-form reasoning, secrets, private credentials, one-time device codes, or environment dumps.

