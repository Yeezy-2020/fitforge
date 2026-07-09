# FitForge Module Map

last_verified_commit: `71b38dfc3f8b`
last_verified_date: `2026-07-09 UTC`

This map describes current module responsibilities and complexity hot spots. Verify against live code before relying on it for implementation work.

## Module Inventory

| Module | Responsibility | Key files | Complexity | Boundary |
|---|---|---|---|---|
| App / Shell / Auth | App startup, Supabase initialization, GoRouter routing, login/onboarding, bottom navigation. | `lib/main.dart`, `lib/app.dart`, `lib/features/auth/`, `lib/features/home/home_shell.dart` | Medium | Coordinate entry/session/navigation; avoid business calculations here. |
| Providers | Riverpod global state, caches, active program/date selection, profile/diet/workout lists. | `lib/providers/app_providers.dart`, `lib/providers/settings_providers.dart` | High | Connect UI to local/remote data; avoid adding more domain logic directly here. |
| Data / Persistence | SecureStorage JSON persistence, user-scoped keys, exercise library, local queues. | `lib/data/repositories/app_database.dart`, `lib/data/repositories/exercise_library.dart` | High | Local persistence only; remote writes belong in service/sync layer. |
| Sync / Remote | Supabase Auth/Profile/Food/Workout/Diet access and sync orchestration. | `lib/core/services/supabase_service.dart`, `lib/core/services/sync_service.dart` | Medium | Does not currently cover training-program remote sync. |
| Workout | Calendar, workout day logging, templates, exercise detail, rest timer, workout UI. | `lib/features/workout/**`, `lib/data/models/workout_log.dart`, `lib/data/models/progression_rule.dart` | High | Screens should orchestrate UI; domain rules should move toward models/utils/services. |
| Training Program | Program/day/exercise model, cycle scheduling, pause/end, deload, prescriptions, completion advancement. | `lib/data/models/training_program.dart`, `lib/core/utils/program_prescription_calculator.dart`, `lib/features/workout/screens/program_detail_screen.dart` | High | Keep rules in domain/model helpers; avoid embedding scheduling rules in widgets. |
| Diet / Nutrition | Food logs, meal templates, nutrition-plan targets, macro calculations, diet-progress display. | `lib/features/diet/`, `lib/features/nutrition_plan/`, `lib/core/utils/nutrition_calculator.dart`, `lib/data/models/nutrition_plan.dart` | High | Diet records actual intake; nutrition plan computes targets and should remain explainable. |
| Body / Settings / Subscription / i18n / Theme | Body measurements, profile/settings, local Pro unlock, localization, visual system. | `lib/features/body/`, `lib/features/settings/`, `lib/features/subscription/`, `lib/core/localization/l10n.dart`, `lib/core/theme/` | Low-Medium | Visible text should use L10n; Pro unlock is not production purchase verification. |

## Current Size Signals

- Dart total in `lib`, `test`, and `integration_test`: about 18.3k lines.
- `lib/features/workout`: about 5.6k lines.
- `lib/features/diet` + `lib/features/nutrition_plan`: about 2.1k lines.
- Static test declarations observed with `rg "testWidgets|test\\(" test integration_test -n | wc -l`: 209.

## Hot Spots

- `lib/features/workout/screens/program_detail_screen.dart`: 2019 lines.
- `lib/features/workout/screens/workout_day_screen.dart`: 1529 lines.
- `lib/features/nutrition_plan/screens/nutrition_plan_screen.dart`: 1360 lines.
- `lib/data/models/training_program.dart`: 1256 lines.
- `lib/data/repositories/app_database.dart`: 861 lines.
- `lib/providers/app_providers.dart`: 584 lines.

## Split Candidates

- Split training-program edit UI into day, exercise, deload, activation, and action widgets.
- Move training-program scheduling, pause, deload refresh, and prescription behavior toward focused domain helpers.
- Split `app_providers.dart` by domain once Riverpod dependency boundaries are clearer.
- Split `AppDatabase` into user-scoped repository slices or storage adapters before adding more local-only entities.
- Keep Diet and Nutrition linked but avoid putting target-calculation behavior inside screens.

