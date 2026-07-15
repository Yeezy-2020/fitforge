# Real-Device Smoke Retry

last_verified_commit: `18cb461`
task_status: `partial`
owner: `fitforge-general-contractor`
created_at: `2026-07-15 UTC`
updated_at: `2026-07-15 UTC`

## Summary

Retried the training-program smoke on the existing Redmi K20 Pro. A first
replacement attempt over EasyTier dropped the phone peer, but the user then
provided the same-LAN address `192.168.31.56`. LAN ADB was authorized, the
same-signed 23.3 MB release APK installed successfully with app data preserved,
and a timeboxed TP-01 through TP-13 smoke was executed.

The executed happy paths found no FitForge product defect or process crash.
TP-01, TP-02, and TP-04 passed. The key deload, activation, pause/resume,
Add-all/save/advance, localization/unit, restart, and rotation paths also passed,
but several exhaustive subcases remain partial, blocked by ADB gesture fidelity,
or deliberately timeboxed.

## Safety And Data Handling

- Reused fixed adbd port 5555 first at `10.126.126.3`, then at the verified LAN
  address `192.168.31.56`; no pairing or ADB-key removal was performed.
- The lock screen reported no PIN/pattern credential and was dismissed only with
  the standard Android keyguard command.
- The successful install used `adb install --no-streaming -r`; no uninstall,
  clear-data, downgrade, or account sign-out command was used.
- The existing disposable login credentials were neither requested nor exposed.
- Package first-install time and encrypted storage remained intact. The
  authenticated session survived; a missing local profile correctly routed to
  Onboarding, which was completed through the UI with disposable test values.
- ADBKeyboard was used temporarily for deterministic English input. The original
  MIUI iFlytek IME, English/kg preferences, and automatic portrait rotation were
  all restored and verified before exit.

## Device And Connectivity Evidence

- Device: Redmi K20 Pro (`raphael`), Android 11 / API 30.
- Display: 1080x2340 at 440 dpi.
- Power: awake, display on, AC powered, battery 100%.
- Initial state: ping reachable at about 93.6 ms; ADB state `device`, not
  `offline` or `unauthorized`; persistent ADB port still `5555`.
- Existing package before retry: `com.fitforge.fitforge` 1.0.0 (1), last updated
  on 2026-07-11; FitForge was not running or foreground.
- Failure boundary: the 189,966,669-byte streamed debug replacement returned no
  PackageManager reason, then ADB became offline and `10.126.126.3` stopped
  responding entirely.
- Host-side NET-001 remained healthy: system `easytier.service` active, `tun0`
  up at `10.126.126.2/24`, and other peers present. The Redmi peer was absent
  from `easytier-cli peer` through the final retry.
- The timing suggests the large transfer may have contributed, but the evidence
  does not prove causality.
- Same-LAN recovery then passed: ping about 23.4 ms, TCP/5555 open,
  `adb get-state=device`, and identity `Redmi K20 Pro / raphael`.
- The version-code 1 release APK installed with `Success`. MainActivity cold
  launch returned `Status: ok` in 1,035 ms; the final target PID remained alive.

## Current-Worktree Artifacts

All artifacts were built from `18cb461` plus the current uncommitted worktree;
the build-input fingerprint remained unchanged during each build.

| Purpose | Artifact | Bytes | Version code | SHA-256 | Decision |
|---|---|---:|---:|---|---|
| Debug diagnostics | `build/app/outputs/flutter-apk/app-debug.apk` | 189,966,669 | 1 | `8e8fdc453255a8b9409968d5181e21924467d81ecc999cfdf60b4d35bfd22171` | Do not retry over the VPN path while the small artifact is available. |
| Preferred remote retry | `build/app/outputs/flutter-apk/app-release.apk` | 23,255,260 | 1 | `a28477b6dfc4d8ed2f3eb1f5867b6ee3218d7e7da2fd74974f8c7ed9ef78fdc4` | Preferred: same version code and signing certificate as the installed/debug package. |
| ARM64 split backup | `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` | 23,032,156 | 2001 | `fc2d38cde1859eb26f30cf929c2185c8c9013bc4a73f034ae5b61068d25f213e` | Avoid by default because returning to version-code 1 debug builds would be a downgrade. |

The debug and release certificates share SHA-256
`3f1291fae6c2fe3955e9f90b732b9a09a9722499892fa1fef32f646d8cd742bb`.
APK v2 signature verification passed.

## Checklist Result

| ID | Result | Notes |
|---|---|---|
| TP-01 | Pass | Invalid zero cycles was blocked; finite blank and starter programs were created; starter Push/Pull/Legs/Rest days rendered. |
| TP-02 | Pass | Finite-2 and continuous summaries rendered; active finite projection showed Jul 24 and scheduled continuous showed until ended. |
| TP-03 | Partial / blocked | Add, rename, type change, delete, button-region boundary, numbering, and reopen persistence passed. One title-region ADB drag did not trigger reorder, so real long-press reorder remains unverified rather than failed. |
| TP-04 | Pass | Existing exercise invalid/save/edit/remove paths passed; `Smoke Custom 20260715` persisted after navigation. |
| TP-05 | Partial / timeboxed | No-base block, standard deload insertion/copy, 40 -> 28 kg reduction, label, position, and calendar marker passed. Volume and custom variants were skipped. |
| TP-06 | Partial / timeboxed | Source Squat 40 -> 60 kg refreshed linked deload 28 -> 42 kg and retained the day. Source add/remove matrix was skipped. |
| TP-07 | Partial / timeboxed | Future continuous scheduling for Jul 16 passed; date-arrival selection behavior was not advanced in real time. |
| TP-08 | Partial / timeboxed | Immediate Core activation retired the future schedule and displayed active/projected state. Full current-plus-future coexistence matrix was skipped. |
| TP-09 | Partial / timeboxed | Pause from today and resume today passed. Earlier-date and End paths were skipped; Core remains active. |
| TP-10 | Partial; happy path pass | Add all created five pending planned entries; one save produced `Workout saved · Program advanced` and moved the current program day to Standard deload. Partial/manual/backfill/rest/manual-mode cases were skipped. |
| TP-11 | Skipped / timeboxed | A same-slot log older than seven days was not constructed after the fast-smoke scope change. |
| TP-12 | Partial; spot-check pass | Chinese program/workout copy and kg -> lb conversions passed; settings were restored to English/kg. Full dialog-copy matrix was skipped. |
| TP-13 | Partial; fast checks pass | Force-stop/restart preserved login/data; portrait/landscape rendered and device rotation was restored. Cross-account isolation still requires a second confirmed disposable account. |

## Remaining Manual Coverage

1. Perform a human long-press reorder and confirm persistence; the single ADB
   swipe did not engage Flutter's delayed drag listener.
2. Complete volume/custom deload variants and source add/remove refresh.
3. Exercise scheduled current-plus-future coexistence across the actual start
   date, earlier-date pause/resume, and End behavior.
4. Run the TP-10 partial/manual/backfill/rest/manual-mode matrix.
5. Construct a same-slot log older than seven days and run TP-11 plus the full
   long-break localization/unit matrix.
6. Use a second confirmed disposable account for TP-13 cross-account validation.

## Validation And Evidence

- Current-worktree debug build: passed in 43.20 seconds.
- Current-worktree release build: passed in 76.51 seconds.
- APK manifest, ABI, hash, and v2 signature checks: passed.
- Connectivity evidence:
  `/tmp/fitforge-smoke/2026-07-15-connectivity/`
- Failed-install evidence:
  `/tmp/fitforge-smoke/2026-07-15-install/install-stage.txt`
- Successful LAN install/startup evidence:
  `/tmp/fitforge-smoke/2026-07-15-lan-install/`
- TP-01 through TP-13 screenshots, UI XML, restored-settings evidence, and final
  PID logcat:
  `/tmp/fitforge-smoke/2026-07-15-lan-checklist/`
- Build evidence:
  `/tmp/fitforge-smoke/2026-07-15-build/` and
  `/tmp/fitforge-smoke/2026-07-15-build-arm64/`

- Final PID logcat: 61 lines; zero matches for fatal exception, ANR,
  AndroidRuntime crash, native fatal signal, FlutterError, or unhandled exception.
- `git diff --check`: passed after project-record updates.

AND-001 was updated in ops-docs with the verified same-LAN
`192.168.31.56:5555` route; catalog, changelog, and generated index were updated
in the same turn.
