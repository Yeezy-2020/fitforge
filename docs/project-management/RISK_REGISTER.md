# FitForge Risk Register

last_verified_commit: `79d65df`
last_verified_date: `2026-07-09 UTC`

Use this register for active product, architecture, data, release, and AI-operation risks. Re-verify each risk against code before acting on it.

| ID | Priority | Area | Risk | Impact | Likelihood | Mitigation | Trigger | Owner |
|---|---|---|---|---|---|---|---|---|
| R-01 | P0 | Sync / local-first | Training programs, progression rules, and workout set logs are local-first; remote sync is incomplete for plan context. | Multi-device restore can lose training-plan progression context. | High | Design Supabase schema, migration, conflict strategy, and explicit local-only labeling. | Training plans move toward production use. | Data / Backend |
| R-02 | P0 | Training / progression | Prescriptions depend on program/day/exercise slot identity and local set logs. Remote workout logs alone may not reconstruct plan slots. | Progression suggestions can be wrong after restore or device switch. | High | Persist programId/dayId/exerciseId or add a remote set-log table before relying on cross-device progression. | Multi-device or restore support. | Workout |
| R-03 | P0 | Pro / billing | Paywall can enable Pro locally without production entitlement verification. | Paid access can be spoofed or misunderstood as production-ready. | High | Keep as development-only; integrate RevenueCat/store entitlement and server-side verification before paid launch. | Paid launch or external beta. | Product / Billing |
| R-04 | P1 | User isolation | Some async providers read current user id imperatively; guards are stronger in training-program paths than elsewhere. | Cross-account writes or stale async updates during logout/switch. | Medium | Standardize expectedUserId checks and user-scoped provider rebuild patterns. | Auth/session refactor or sync expansion. | App |
| R-05 | P1 | Persistence | SecureStorage stores JSON blobs without schema versioning, migration tests, or corruption recovery. | Field changes can break existing local data. | Medium | Add storage versioning, migration tests, and conservative decode fallback. | Model/schema changes. | Data |
| R-06 | P1 | i18n / units | Visible hard-coded text can remain outside L10n, especially in complex screens. | Chinese/English mode regressions and inconsistent UX. | High | Require L10n for all visible text and add focused widget coverage for new screens. | Any UI feature. | UI |
| R-07 | P2 | CI / docs | CI does not yet match local pre-push gates, and README can drift from actual tests/analyzer state. | Future agents or maintainers can trust stale docs. | Medium | Add analyze/dead-button checks to CI and keep project-management docs verified by commit. | Before regular release cadence. | Release |
| R-08 | P1 | QA / mobile-only | Current host has no Android/iOS device or AVD emulator, so the mobile manual smoke checklist cannot be executed here. | Mobile-only touch/layout regressions can escape local verification. | Medium | Provision a physical mobile test device or Android AVD, then execute `TRAINING_PROGRAM_SMOKE_CHECKLIST.md`. | Before mobile release or after touch-heavy training-program changes. | Release / UI |

## Priority Summary

- P0: R-01, R-02, R-03
- P1: R-04, R-05, R-06, R-08
- P2: R-07
