# Daily Report: Phase 1 baseline

Target: exact OpenProject `v17.8.0`, maintained as a native core fork on branch
`daily-report-core-v17-8`.

## Verified integration points

- Work Package tabs are registered by
  `frontend/src/app/features/work-packages/components/wp-tabs/services/wp-tabs/wp-tabs.service.ts`.
  Its `registerBefore("activity", tab)` operation is the minimal placement point.
- The default Work Package detail tab is selected in
  `frontend/src/app/features/work-packages/routing/split-view-routes.template.ts`.
  The current redirect chooses `overview`; Daily Report will replace that only
  after its tab is registered and covered by focused frontend tests.
- Existing in-app notifications are work-package-specific. In particular,
  `Notifications::Scopes::Visible` filters to `resource_type = "WorkPackage"`
  and the standard workflow consumes journals. Daily Report must not manufacture
  a journal, comment or activity. Its Phase 4 implementation needs an explicit
  resource/link/visibility extension and tests for preference, visibility,
  actor exclusion and deduplication.

## Local verification

The WSL2 Docker stack has PostgreSQL, cache, Rails backend, worker, frontend
and Hocuspocus running. The backend responds at `http://localhost:3000` and a
Rails runner confirmed database access.

## Deferred product decisions

School-day representation, cross-project elevated access, deletion/retention,
notification batching, legacy dashboard workflow and PDF shape are deliberately
outside the first schema/UI increment until confirmed. The initial increment
will use only the confirmed per-work-package entry fields and native visibility.
