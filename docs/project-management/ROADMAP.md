# FitForge Roadmap

last_verified_commit: `18cb461`
last_verified_date: `2026-07-15 UTC`

## Month 1: Mobile Training Stabilization

Status: automated stabilization is locally complete; the 2026-07-15 LAN fast
smoke passed the core program, deload, activation, save/advance, localization,
restart, rotation, and stability paths without finding a product defect.

- Keep training-program creation/edit/activation/deload/logging/advancement tests green.
- Complete only the remaining manual/timeboxed subcases recorded in
  `TRAINING_PROGRAM_SMOKE_CHECKLIST.md`; use same-LAN ADB and the prepared
  same-signed 23.3 MB version-code 1 release APK.
- Use device findings, not speculative refactors, to reopen P1 defects.

Exit criteria:

- Full mobile checklist evidence exists, or each skipped item is explicitly accepted for the target release.

## Month 2: Sync Activation And Data Reliability

Status: schema-first code foundation is complete locally and defaults off.

- Apply and validate the additive Supabase migration in a disposable project.
- Run RLS/FK, two-account restore, delete tombstone, rollback, and conflict smoke.
- Decide whether latest-write-wins is adequate before enabling the feature flag.
- Continue lower-risk storage versioning only after activation behavior is known.

Exit criteria:

- Migration and rollback evidence is recorded.
- The capability is either deliberately enabled or remains off with a documented blocker.

## Month 3: Release Readiness

- Replace local Pro unlock with production entitlement verification when the deferred billing work resumes.
- Assess Google/Apple login scope.
- Recheck release APK size against the 23,255,260-byte arm64 baseline.
- Exercise the updated CI/Pages workflow after an approved push.
- Decide whether module splitting, dependency upgrades, and stronger storage transactions are required for the release.

Exit criteria:

- Mobile smoke, entitlement, sync activation, CI, packaging, and rollback gates are explicitly passed or deferred by release decision.
