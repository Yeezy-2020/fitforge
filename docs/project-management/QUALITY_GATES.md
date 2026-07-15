# FitForge Quality Gates

last_verified_commit: `18cb461`
last_verified_date: `2026-07-15 UTC`

## Local Development

- Use `/home/dyy/flutter/bin/flutter` when available.
- Set `NO_PROXY=localhost,127.0.0.1 no_proxy=localhost,127.0.0.1` for Flutter tests on this host.
- Run strict analysis for changed code: `/home/dyy/flutter/bin/flutter analyze --no-pub`. Analyzer infos and warnings are treated as work to fix, not a release baseline.
- Match tests to risk: pure domain/unit tests, provider/storage tests, widget tests, and existing goldens.
- Visible copy must use `L10n` with English and Chinese coverage.
- Training copy must keep `test/features/training_program_wording_guard_test.dart` green.

## Focused Gates

High-risk training/sync/auth changes should include the relevant subset of:

```bash
NO_PROXY=localhost,127.0.0.1 no_proxy=localhost,127.0.0.1 /home/dyy/flutter/bin/flutter test --no-pub test/core/services/workout_log_builder_test.dart
NO_PROXY=localhost,127.0.0.1 no_proxy=localhost,127.0.0.1 /home/dyy/flutter/bin/flutter test --no-pub test/core/services/training_program_editor_test.dart
NO_PROXY=localhost,127.0.0.1 no_proxy=localhost,127.0.0.1 /home/dyy/flutter/bin/flutter test --no-pub test/data/app_database_training_sync_outbox_test.dart
NO_PROXY=localhost,127.0.0.1 no_proxy=localhost,127.0.0.1 /home/dyy/flutter/bin/flutter test --no-pub test/core/services/sync_service_test.dart
NO_PROXY=localhost,127.0.0.1 no_proxy=localhost,127.0.0.1 /home/dyy/flutter/bin/flutter test --no-pub test/screens/auth_flow_test.dart
NO_PROXY=localhost,127.0.0.1 no_proxy=localhost,127.0.0.1 /home/dyy/flutter/bin/flutter test --no-pub test/screens/workout_day_user_scope_test.dart
```

Storage changes must preserve legacy reads, fail closed on corrupt/future/foreign-owner envelopes, avoid read-time rewrites, and prove unrelated bytes remain unchanged.

## Pre-Push Gate

Run:

```bash
bash scripts/pre_push.sh
```

The script runs analyzer, the full Flutter test suite, widget dump smoke, and a dead-button scan. Any failure blocks push. Run strict `flutter analyze --no-pub` separately because the script currently passes non-fatal analyzer flags.

The 2026-07-13 stabilization batch passed locally:

- integrated focused suite: 86/86
- final Workout account/single-flight suite: 11/11
- strict analyzer: no issues
- full `scripts/pre_push.sh`: all passed, including zero dead buttons

## Training-Sync Activation Gate

Static migration assertions and local mocks are not a real database migration test. Before enabling `FITFORGE_TRAINING_SYNC_V1`:

1. Apply `supabase/migrations/202607130001_training_sync_foundation.sql` to a disposable Supabase/PostgreSQL project.
2. Verify migration idempotence, constraints, indexes, triggers, RLS, and same-owner foreign keys.
3. Run two-account upsert/delete/restore and offline enabled -> disabled -> enabled recovery smoke.
4. Confirm legacy sync does not revive tombstones.
5. Enable the flag only through an explicit release decision.

## Android Build And Size

- Build the current worktree; do not reuse an unknown APK.
- Current-worktree 2026-07-15 release APK: `23,255,260` bytes (about 22.18 MiB), SHA-256 `a28477b6dfc4d8ed2f3eb1f5867b6ee3218d7e7da2fd74974f8c7ed9ef78fdc4`, package/version `com.fitforge.fitforge` 1.0.0 (1). It shares the debug signing certificate and is the preferred remote-smoke replacement artifact.
- Current-worktree debug APK: `189,966,669` bytes, SHA-256 `8e8fdc453255a8b9409968d5181e21924467d81ecc999cfdf60b4d35bfd22171`. Do not stream this large artifact over the EasyTier phone path when the smaller same-signed release APK is available.
- The ARM64 split artifact is slightly smaller but receives version code 2001; avoid installing it by default because returning to version-code 1 debug builds would require a downgrade path.
- Largest packaged native artifacts observed: `libflutter.so` 11,579,920 bytes and `libapp.so` 8,848,272 bytes; `classes.dex` 4,953,236 bytes.
- Record device model/API/resolution, install mode, artifact hash, and target-PID crash/ANR review for mobile smoke.
- For remote-device replacement, preserve app data and account state: verify the
  phone peer and ADB `device` state, prefer `adb install --no-streaming -r` with
  the version-code 1 release APK, and never use uninstall or clear-data as a
  smoke prerequisite.
- 2026-07-15 Redmi K20 Pro / Android 11 LAN fast smoke used
  `192.168.31.56:5555`. Install and cold launch passed, core TP happy paths
  passed, and the final 61-line target-PID logcat had zero crash/ANR/Flutter
  error matches. Remaining timeboxed/manual subcases stay release-gated in the
  checklist and task report.

## CI And Deployment

- `.github/workflows/deploy.yml` now runs `bash scripts/pre_push.sh` before the Web preview build and Pages deployment.
- Confirm the updated workflow in remote CI for every approved push before
  treating the Pages preview or release gate as green.
- Web/Pages remains an internal preview; Android/iOS are the supported product targets.
- After an approved push, confirm `origin/main`, Actions, and `https://yeezy-2020.github.io/fitforge/` before reporting deployment complete.
