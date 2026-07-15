# Android Smoke Bootstrap

last_verified_commit: `18cb461`
task_status: `partial`
owner: `fitforge-general-contractor`
created_at: `2026-07-13 UTC`
updated_at: `2026-07-13 UTC`

## Summary

Provisioned a user-local Android toolchain, paired and verified a physical Redmi K20 Pro, built the current uncommitted FitForge worktree, completed a first-install/login-screen startup smoke, created a disposable confirmed test user, and began the training-program checklist. The phone is no longer available, so execution is paused after the TP-01 empty-name assertion.

## Environment

- Device: Xiaomi Redmi K20 Pro (`raphael`), Android 11 / API 30, 1080x2340 at 440 dpi.
- JDK: Eclipse Temurin 17.0.19+10 under `/home/dyy/.local/jdk-17.0.19+10`.
- Android SDK: `/home/dyy/Android/Sdk`, with cmdline-tools 21, Platform 36, Build Tools 36.0.0, Platform Tools 37.0.0, and build-required CMake 3.22.1.
- ADB: wireless pairing succeeded; connect ports changed after wireless-debugging restarts, so each session must use the currently advertised mDNS service.

## Build And Host Stability

- The first Gradle attempt was killed by a global host OOM, not a source or Gradle compile error.
- Root cause was 70 orphaned `claude mcp serve` processes using about 4.2 GiB, with host RAM and swap exhausted. Only PPID-1 orphan processes were terminated; active Codex MCP processes were preserved.
- Host-local `~/.gradle/gradle.properties` bounds Gradle to a 1.5 GiB heap, uses one worker and in-process Kotlin, and disables parallel/long-lived daemon behavior. Repository-wide Android settings remain unchanged for other developers and CI.
- The successful debug build used the cached dependency/toolchain state and produced `build/app/outputs/flutter-apk/app-debug.apk`.
- Artifact size: 163,854,506 bytes.
- Artifact SHA-256: `f28d41dff0f98894437b54d314bc68c214341271d29e27411f4c3850b2738c44`.
- Gradle `assembleDebug` completed in 347.4 seconds. Warnings remain for plugin Built-in Kotlin migration and SDK XML version compatibility; neither blocked the build.

## Device Startup Smoke

- Confirmed `com.fitforge.fitforge` was not previously installed before using a normal first-install command; no replace, downgrade, clear-data, or uninstall flag was used.
- Installed package: version 1.0.0, code 1.
- `am start -W` returned `Status: ok`; `MainActivity` remained foreground with a stable FitForge PID.
- Target-PID log review found no error, fatal exception, ANR, unhandled exception, or native fatal signal.
- Login portrait evidence: `/tmp/fitforge-smoke/2026-07-11-startup/login-portrait.png`.
- The 1080x2340 login layout had no visible clipping or overlap.

## Smoke Findings

1. Login UI mixes languages: Email/Password/Sign up remain English while the primary action displays Chinese. Record under TP-12/i18n.
2. A newly confirmed user logged in successfully but bypassed onboarding and landed directly on the Workout home screen. The account had no prior app data. Record as an auth/onboarding routing defect.
3. TP-01 empty-name validation passed: submitting a blank program name kept the dialog open, displayed `Enter a program name.`, and did not create a program.
4. The remaining blank/starter creation checks, TP-02, and TP-03 through TP-13 were not executed before the phone became unavailable.

## Data And Credential Handling

- A unique disposable Supabase user was created and email-confirmed through a temporary mailbox; no service-role or admin credential was available.
- The app remains installed and logged into that disposable user on the phone.
- Credentials and auth/mail tokens were not written to the repository or project reports. Local temporary request, session, token, and email files were deleted after login.
- Deleting the remote auth user later requires Supabase Dashboard or service-role access; app logout/local clear alone does not delete the remote identity.

## Resume Point

1. Make the phone available, unlock it, and toggle wireless debugging off/on if mDNS is not advertising a connect service.
2. Reconnect using the current `_adb-tls-connect._tcp` service and confirm physical serial `5a5fba08`.
3. Confirm FitForge is still the foreground/logged-in disposable session and that Programs contains no unexpected data.
4. Resume TP-01 after the completed empty-name assertion; use names prefixed with `Smoke 20260713`.
5. Continue TP-02 through TP-13, capturing short UI XML/log evidence. Wireless screenshot transfer was intermittent, so screenshots should use a bounded device-temp-file flow.

## Remaining Risk

- Full touch/drag/dialog/scheduling/deload/recovery/unit/account-isolation coverage remains incomplete.
- One disposable user is available; TP-13 still needs a second disposable confirmed user.
- The onboarding bypass and mixed-language login screen require separate fixes and focused regression tests.
