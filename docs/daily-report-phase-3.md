# Daily Report — Phase 3: native Work Package UI

Completed against the OpenProject `v17.8.0` core fork.

- The `Daily Report` Work Package tab is registered immediately before
  `Activity`; the split-view route opens it by default.
- The tab uses the authenticated same-origin Rails endpoints and Angular
  `HttpClient`, so native OpenProject sessions and CSRF handling apply.
- It provides plain-text creation for today and previous dates, list/read,
  elevated correction, and administrator-only soft deletion.
- Ausbilder uses the global `manage_daily_report_entries` permission and can
  therefore correct entries across all currently visible Work Packages;
  native Work Package visibility remains mandatory. Server responses expose
  only capability flags calculated from that current authorization. They are
  presentation hints, not authorization; every write remains authorized by
  the service policy.
- Deletion is soft: the entry, its revisions, and its audit trail remain
  preserved. The active-entry uniqueness index permits an administrator to
  remove an erroneous entry without destroying append-only history.

Validation performed:

- focused ESLint on the tab, route, module, and tab-registration sources;
- focused RuboCop on Daily Report backend sources and request specification;
- `spec/requests/work_packages/daily_report_entries_spec.rb`: 6 examples,
  0 failures, including IDOR and delete authorization cases;
- both Daily Report migrations applied successfully to the local WSL
  development and test databases.

Not part of this phase: watcher notifications (Phase 4), school-day policy,
management/history screens, PDF export, and deployment packaging.
