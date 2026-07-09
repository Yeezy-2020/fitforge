# FitForge Decision Log

last_verified_commit: `71b38dfc3f8b`
last_verified_date: `2026-07-09 UTC`

Record durable product and architecture decisions here. Do not use this file for task notes, temporary handoff state, or raw agent reasoning.

## Decisions

| Date | Decision | Rationale | Consequences | Source |
|---|---|---|---|---|
| 2026-07-09 | Keep FitForge formally mobile-only; use Web/GitHub Pages only for internal preview and deployment checks. | The product target is iOS/Android, while Web remains useful for CI and smoke checks. | Web build must stay healthy for preview, but Web-specific UX should not drive product scope. | `README.md`, `QUALITY_GATES.md` |
| 2026-07-09 | Use `docs/project-management/` as the project-management knowledge base, with code/tests/git as the higher source of truth. | Long-running AI-assisted work needs stable local docs without treating docs as absolute truth. | Non-trivial tasks should update task reports and relevant governance docs. | `INDEX.md`, skill rule |
| 2026-07-09 | Do not commit `HANDOFF.md`; keep it as a temporary local handoff artifact. | Handoff files become stale quickly and may contain transient operational context. | `HANDOFF.md` is ignored by git; durable facts belong in project-management docs. | `.gitignore`, `INDEX.md` |

