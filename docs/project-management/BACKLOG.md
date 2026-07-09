# FitForge Backlog

last_verified_commit: `71b38dfc3f8b`
last_verified_date: `2026-07-09 UTC`

This backlog is a working queue. Re-rank it when product goals change or after major implementation work.

## Epics

- Training Program Stabilization: cycle scheduling, pause/resume/end, deload, prescriptions, completion advancement, long-gap recovery.
- Data Reliability And User Isolation: local storage schema, Supabase sync, account switching, restore behavior.
- Product Completeness: nutrition/diet/body loops, paid entitlement verification, OAuth, mobile release readiness.
- Project Governance: module map, risk register, quality gates, task reports, README accuracy.

## P0

- Feature: Manual smoke test the full training-plan flow: create, edit days, finite/continuous cycles, activate by date, pause/resume, end, add deload, save workout, confirm advancement.
- Bug/Risk: Local `main` is ahead of `origin/main` by 1 commit; deployment state must be rechecked after the next approved push.
- Tech debt: Commit and maintain project-management docs so future agents do not rely on stale chat context.
- Tech debt: Keep README aligned with actual CI/test/analyzer behavior.

## P1

- Feature: Add long-gap recovery prompt when returning after a long break from a program slot.
- Bug: Search and remove remaining natural-week wording from progression UI/copy where behavior is cycle/round based.
- Tech debt: Split training-program detail UI and move domain rules out of screens.
- Tech debt: Add storage versioning and migration tests before more local model fields are added.
- Tech debt: Expand user-isolation tests for async provider writes and account switching.

## P2

- Feature: Google and Apple login.
- Feature: Production purchase/entitlement verification for Pro.
- Tech debt: Move CI closer to local pre-push gates.
- Tech debt: APK/app size assessment before mobile release packaging.
- Tech debt: Clean analyzer info baseline where it is low-risk.

## Not Now

- Do not treat Web/GitHub Pages as a formally supported platform.
- Do not expand into complex AI coaching or advanced periodization UX before the training-plan core stabilizes.
- Do not redesign the whole visual system unless readability or core-flow usability requires it.
- Do not expose production-grade Pro behavior before real entitlement verification exists.

