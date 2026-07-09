# FitForge Roadmap

last_verified_commit: `800a1f1`
last_verified_date: `2026-07-09 UTC`

This roadmap covers the next 1-3 months at a lightweight internet-product planning level. It should guide sequencing, not freeze scope.

## Month 1: Training Program Stabilization

Goals:

- Make the current training-plan flow reliable enough for repeated mobile use.
- Close obvious copy, i18n, and interaction gaps around cycle/round progression.
- Keep new training-plan work covered by focused tests and task reports.

Candidate work:

- Execute the mobile smoke checklist for program creation, edit, activation, date scheduling, pause/resume/end, deload, logging, and advancement.
- Long-gap recovery prompt design and implementation.
- Training-program UI split plan for `program_detail_screen.dart` and `workout_day_screen.dart`.
- Keep cycle-vs-week wording clean as future progression and scheduling copy changes.

Exit criteria:

- Training program flows have repeatable test/smoke coverage.
- Known P0 training-plan risks are either mitigated or explicitly deferred in `RISK_REGISTER.md`.

## Month 2: Data Reliability And Account Boundaries

Goals:

- Make local-first behavior explicit and safer.
- Prepare for eventual multi-device restore without rushing a broad migration.

Candidate work:

- Storage versioning and decode fallback plan for `AppDatabase`.
- User-isolation audit for providers and async write paths.
- Supabase schema design for training programs and set-level progression context.
- Sync conflict/error-handling strategy.

Exit criteria:

- Data-layer changes have migration/rollback notes.
- User switching and local/remote write paths have targeted tests or documented limitations.

## Month 3: Mobile Release Readiness

Goals:

- Prepare the app for real mobile distribution decisions.
- Close production-only gaps before external release.

Candidate work:

- Production Pro entitlement verification.
- Google/Apple login assessment and implementation plan.
- CI improvements matching local gates.
- APK/app size assessment and mobile release checklist.

Exit criteria:

- Release checklist exists and is followed.
- Pro/OAuth/mobile packaging risks are either resolved or explicitly out of scope for the release.
