# FitForge Quality Gates

last_verified_commit: `71b38dfc3f8b`
last_verified_date: `2026-07-09 UTC`

These gates define the expected checks before committing, pushing, or deploying FitForge work.

## Local Development

- Use the repo Flutter binary when available: `/home/dyy/flutter/bin/flutter`.
- For Flutter tests in this environment, set `NO_PROXY=localhost,127.0.0.1 no_proxy=localhost,127.0.0.1`.
- New product behavior should include tests at the right level:
  - model/formula/serialization: unit tests under `test/features/`
  - screen rendering and button availability: widget tests under `test/screens/`
  - visual regressions: golden tests where the screen already has golden coverage
- Visible text changes must use `L10n` and include English and Chinese strings.

## Pre-Commit Gate

Run the smallest checks that cover the touched area:

```bash
/home/dyy/flutter/bin/flutter analyze --no-fatal-infos --no-fatal-warnings
NO_PROXY=localhost,127.0.0.1 no_proxy=localhost,127.0.0.1 /home/dyy/flutter/bin/flutter test test/features/training_program_test.dart
```

Use focused tests appropriate to the changed module. For doc-only changes, markdown review and git diff inspection are enough unless README claims test/analyzer status.

## Pre-Push Gate

Use:

```bash
bash scripts/pre_push.sh
```

The script currently runs:

- `flutter analyze --no-fatal-infos --no-fatal-warnings`
- `flutter test`
- widget dump smoke via `test/dump_test.dart --plain-name "pill"`
- dead-button scan for `onPressed: () => {}`

The script resolves Flutter in this order: `/home/dyy/flutter/bin/flutter`, `/opt/flutter/bin/flutter`, then `flutter` from `PATH`.

It also sets `NO_PROXY` and `no_proxy` for `localhost,127.0.0.1` so Flutter test WebSocket traffic is not routed through external proxies in this environment.

Any failure blocks push.

## Delegation And Review

- Non-trivial FitForge work should use `gpt-5.5/high` workers.
- Each worker or reviewer must return the structured agent report required by the skill.
- Independent review is required for training-program/progression, storage/sync, auth/user isolation, subscription/Pro, i18n-heavy UI, CI/deploy, and broad refactors.
- Main Codex must verify findings against code before acting.

## CI And Deployment

Current GitHub Actions workflow:

- `.github/workflows/deploy.yml`
- triggers on `push` to `main` and `workflow_dispatch`
- runs `flutter pub get`, `flutter test`, and `flutter build web --release --base-href /fitforge/`
- deploys the Web preview to GitHub Pages

CI gaps to close:

- add `flutter analyze --no-fatal-infos --no-fatal-warnings`
- add dead-button scan or reuse equivalent `scripts/pre_push.sh` logic
- consider PR checks before `main`
- consider Flutter version pinning or documented stable-channel drift
- keep Web/GitHub Pages as internal preview only; iOS/Android are the supported platforms

## Deployment Follow-Up

After an approved push or deploy:

1. Confirm `origin/main` equals local `HEAD`.
2. Check latest GitHub Actions run status.
3. Verify Pages URL: `https://yeezy-2020.github.io/fitforge/`.
4. Use the test account only for smoke checks already documented in the skill.
5. Report commit, Actions/Pages status, and any blockers.
