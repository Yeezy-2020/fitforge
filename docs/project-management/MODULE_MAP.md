# FitForge Module Map

last_verified_commit: `18cb461`
last_verified_date: `2026-07-13 UTC`

## Module Inventory

| Module | Responsibility | Key files | Complexity / boundary |
|---|---|---|---|
| App / Auth / Routing | Startup, stable GoRouter, auth classification, session transitions, onboarding, cache/sync initialization. | `lib/app.dart`, `lib/features/auth/` | Keep session orchestration here; profile load failures must not masquerade as onboarding. |
| Providers | Riverpod state, caches, user scopes, training/workout/profile adapters. | `lib/providers/app_providers.dart`, `settings_providers.dart` | High complexity; all async writes require captured user scope/owner. |
| Local Persistence | User-scoped SecureStorage, v1 envelopes, mutation locks, sync outbox/recovery. | `lib/data/repositories/app_database.dart` | Largest hotspot; local persistence and sync bookkeeping share strict lock/order contracts. |
| Sync / Remote | Supabase access, row codecs, feature flag, serialized sync orchestration, quarantine. | `supabase_service.dart`, `sync_service.dart`, `training_sync.dart`, `sync_row_codec.dart`, migration | Training sync exists but defaults off until real schema/RLS smoke. |
| Training Domain | Programs/days/exercises, scheduling, pause/end, deload, prescriptions, editor transforms. | `training_program.dart`, `training_program_editor.dart`, prescription calculator | Domain helpers own invariants; screens orchestrate UI/provider calls. |
| Workout UI | Calendar, day logging, templates, exercise detail, progression sheet, fixed save attempts. | `lib/features/workout/**`, `workout_log_builder.dart` | User-facing async paths must preserve scope identity and single-flight behavior. |
| Diet / Nutrition | Intake logs, meal templates, macro targets, nutrition planning. | `lib/features/diet/`, `lib/features/nutrition_plan/` | Keep actual intake separate from explainable target calculation. |
| Body / Settings / Subscription / i18n / Theme | Measurements, profile/settings, local Pro development state, localization, visuals. | matching feature folders, `l10n.dart`, theme | Visible copy uses `L10n`; local Pro is not a production entitlement. |

## Current Size Signals

- Dart in `lib`: 20,081 lines.
- Dart in `lib`, `test`, and `integration_test`: 31,975 lines.
- `lib/features/workout`: 6,154 lines.
- Diet + nutrition-plan features: 2,145 lines.
- Static `test`/`testWidgets` declarations: 401.
- `app.dart`: 386 lines.
- `app_database.dart`: 2,110 lines.
- `app_providers.dart`: 1,201 lines.
- `sync_service.dart`: 968 lines; `supabase_service.dart`: 553 lines.

## Screen Families And Domain Helpers

- Program-detail family: 2,113 lines across coordinator 832, deload 289, overview 458, and exercise dialogs 534.
- Workout-day family: 1,810 lines across coordinator 1,284, exercise card 243, and progression sheet 283.
- `training_program_editor.dart`: 136 lines of day/deload transforms.
- `workout_log_builder.dart`: 155 lines of validated save-plan construction.

## Hotspots / Next Splits

- Split `AppDatabase` into storage envelope, training repository, workout repository, and sync journal only after activation contracts stabilize.
- Split `app_providers.dart` by domain when dependency boundaries can remain explicit.
- Continue moving rules from screen coordinators into pure helpers; keep part files for library-private UI composition.
- Do not refactor these hotspots during sync activation unless required by a reproduced defect.
