# FitForge Backlog

last_verified_commit: `800a1f1`
last_verified_date: `2026-07-09 UTC`

This backlog is a working queue. Re-rank it when product goals change or after major implementation work.

## Epics

- Training Program Stabilization: cycle scheduling, pause/resume/end, deload, prescriptions, completion advancement, long-gap recovery.
- Data Reliability And User Isolation: local storage schema, Supabase sync, account switching, restore behavior.
- Product Completeness: nutrition/diet/body loops, paid entitlement verification, OAuth, mobile release readiness.
- Project Governance: module map, risk register, quality gates, task reports, README accuracy.

## P0

- Feature: Execute `TRAINING_PROGRAM_SMOKE_CHECKLIST.md` on mobile/emulator and file failures with evidence.
- Bug/Risk: Local `main` is ahead of `origin/main`; deployment state must be rechecked after the next approved push.
- Tech debt: Keep project-management docs current so future agents do not rely on stale chat context.
- Tech debt: Keep README aligned with actual CI/test/analyzer behavior.

## P1

- Feature: Add long-gap recovery prompt when returning after a long break from a program slot.
- Tech debt: Guard future training-program copy and model names against natural-week wording where behavior is cycle/round based.
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
