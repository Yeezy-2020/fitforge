# Training Program Smoke Checklist

last_verified_commit: `800a1f1`
last_verified_date: `2026-07-09 UTC`

Use this as the repeatable manual checklist for the mobile-only training-program flow. Web/GitHub Pages can help preview, but they are not the supported product target.

## Preconditions

- Use a real mobile device or mobile emulator viewport.
- Sign in with a disposable test account and use unique program names such as `Smoke PPL 2026-07-09`.
- Start from Workout -> Programs unless the step says otherwise.
- Run the full checklist once in English/kg and spot-check changed screens in Chinese/lb.
- Record commit, device, OS, locale, unit, result, evidence, and notes before filing follow-up work.

## Pass / Fail Record

| ID | Result | Device / OS | Locale / Unit | Evidence | Notes |
|----|--------|-------------|---------------|----------|-------|

## Manual Smoke Tests

- [ ] TP-01 Create program: create a blank program with a required name; verify empty name and invalid finite cycle count are blocked. Create a starter program and verify Push/Pull/Legs/Rest days appear.
- [ ] TP-02 Finite/continuous setup: create one finite program with 2 cycles and one continuous program. Verify list/detail summaries show projected end for finite active plans and continuous-until-ended for continuous plans.
- [ ] TP-03 Edit days/reorder: add training and rest days, rename a day, change training/rest type, delete a day, and long-press drag-reorder days on mobile. Verify button regions do not start drag, order persists after navigation, and day numbers update immediately after drop.
- [ ] TP-04 Add exercise: add an existing exercise to a training day, configure sets/reps/start weight/progression, then edit and remove it. Add a custom exercise from the picker. Verify invalid exercise configuration is rejected.
- [ ] TP-05 Add deload: with at least one training day, add standard, volume, and custom deload variants. Verify no-base-day flow blocks creation. Verify deload day label, insertion position, copied exercises, reduced load/volume values, and calendar deload marker.
- [ ] TP-06 Linked deload refresh: create a deload from a source day, then edit/add/remove an exercise on the source day. Verify linked deload exercises refresh while keeping the deload day present.
- [ ] TP-07 Scheduled activation: activate a program for a future date. Verify it shows scheduled, does not show as today's active workout before the date, and appears on calendar/workout views starting on the scheduled date.
- [ ] TP-08 Current/future active behavior: while one program is currently active, schedule another for the future. Verify the current program remains active before the future date; the scheduled program becomes selected on/after its start. Immediate activation should deactivate current and future active plans.
- [ ] TP-09 Pause/resume/end: pause from today and from an earlier date. Verify paused days have no prescriptions and show paused status. Resume from today/earlier date and verify projection continues. End an active/scheduled program and verify markers/prescriptions disappear while the program template and logged workouts remain.
- [ ] TP-10 Log workout and advancement: open today's workout, add all planned prescriptions, save, and verify workout-saved/program-advanced feedback plus next current day. Verify partial planned logs, manual-only logs, backfilled dates, and manual advance mode do not auto-advance. Complete a rest day only on today and verify it advances.
- [ ] TP-11 Long-break prompt readiness: create a prior program-derived log more than 7 days before the selected workout date. Verify the prescription row shows the extended-break prompt and Add All asks whether to use planned load or last load.
- [ ] TP-12 i18n/units: switch English/Chinese and kg/lb. Verify program, activation, pause/resume/end, deload, and long-break copy is localized. Verify workout prescription/pending weights convert to lb; record any kg-only program configuration labels as a unit gap.
- [ ] TP-13 Regression checks: rotate/narrow mobile viewport; verify no clipped dialogs, dead-looking buttons, duplicate active badges, stale scheduled markers, lost custom exercises, or account-crossing data after sign out/in.

## Follow-Up Handling

- File each failed row as a backlog item with device, locale, unit, commit, screenshots or logs, and reproduction steps.
- Add a task report when the checklist is executed or materially changed.
- Keep this checklist aligned with `test/features/training_program_test.dart` and the mobile release checklist.
