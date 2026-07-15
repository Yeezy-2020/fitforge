# Training Program Smoke Checklist

last_verified_commit: `18cb461`
last_verified_date: `2026-07-15 UTC`

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
| TP-01 | Pass | Redmi K20 Pro / Android 11 | English / kg | `/tmp/fitforge-smoke/2026-07-15-lan-checklist/TP-01/` | Invalid cycles, blank/starter creation, and starter days passed. |
| TP-02 | Pass | Redmi K20 Pro / Android 11 | English / kg | `TP-02/`, `TP-08/` | Finite/continuous and projected/continuous summaries passed. |
| TP-03 | Partial / blocked | Redmi K20 Pro / Android 11 | English / kg | `TP-03/` | CRUD/persistence/button boundary passed; ADB drag did not engage delayed reorder. |
| TP-04 | Pass | Redmi K20 Pro / Android 11 | English / kg | `TP-04/` | Existing/custom exercise paths passed. |
| TP-05 | Partial / timeboxed | Redmi K20 Pro / Android 11 | English / kg | `TP-05/` | Standard/no-base/marker passed; volume/custom skipped. |
| TP-06 | Partial / timeboxed | Redmi K20 Pro / Android 11 | English / kg | `TP-06/` | Weight refresh passed; add/remove matrix skipped. |
| TP-07 | Partial / timeboxed | Redmi K20 Pro / Android 11 | English / kg | `TP-07/` | Future schedule passed; date-arrival behavior skipped. |
| TP-08 | Partial / timeboxed | Redmi K20 Pro / Android 11 | English / kg | `TP-08/` | Immediate replacement passed; coexistence matrix skipped. |
| TP-09 | Partial / timeboxed | Redmi K20 Pro / Android 11 | English / kg | `TP-09/` | Today pause/resume passed; earlier/end skipped. |
| TP-10 | Partial; happy path pass | Redmi K20 Pro / Android 11 | English / kg | `TP-10/` | Add all/save/advance passed; matrix skipped. |
| TP-11 | Skipped / timeboxed | Redmi K20 Pro / Android 11 | English / kg | `TP-11/` | Historical same-slot precondition not constructed. |
| TP-12 | Partial; spot-check pass | Redmi K20 Pro / Android 11 | Chinese/English / lb/kg | `TP-12/` | Chinese and weight conversion spot-check passed; settings restored. |
| TP-13 | Partial; fast checks pass | Redmi K20 Pro / Android 11 | English / kg | `TP-13/`, `FINAL/` | Restart/rotation/log scan passed; second-account check skipped. |

Paths without an absolute prefix are relative to
`/tmp/fitforge-smoke/2026-07-15-lan-checklist/`.

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
