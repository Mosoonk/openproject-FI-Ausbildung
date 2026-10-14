# Daily Report upgrade to OpenProject 17.9.1

Date: 2026-10-13

## Source and branch

The upgrade branch `daily-report-core-v17-9-1` starts at the exact upstream
tag `v17.9.1` (`c7ec3efaeb2740944b0368b267901b568d6f2144`). It merges the
Daily Report core-fork history from `daily-report-core-v17-8`, preserving its
feature commits and migration history. The merge completed without textual
conflicts. The existing 17.8 branch and the original `dev` worktree were not
switched or rewritten.

Daily Report remains a native OpenProject customization. Its routes, models,
authorization, four `daily_report_*` migrations, UI, notification handling,
read API and production Compose files are retained in the upgraded branch.
OpenProject's own 17.9.1 changes, including its routes, notification menu,
permissions, locale updates, dependency locks and Hocuspocus image version,
come from the exact upstream tag.

Users can enable or disable `Daily Reports` in **Account settings →
Notification and email → Non-participating**. When enabled, they receive an
in-app notification for each Daily Report created or corrected in every
project where they can view the Work Package. This preference is independent
of Watchers and supports the standard project-specific override.

The image workflow now builds on pushes to this upgrade branch and identifies
the image as based on OpenProject 17.9.1. A manually selected release tag can
be `17.9.1-dr.1` after the branch's checks have passed.

## Data and release handling

The four Daily Report migrations are unchanged from the 17.8 branch. Existing
Daily Report records remain in their dedicated tables. Applying upstream and
Daily Report migrations to any database is a separate release operation: take
and verify database and attachment backups, rehearse the migration against a
restored copy, and run the seeder once for the target stack. No production
database or image was changed as part of this source upgrade.

## Validation status

The merge was checked for conflicts and the final branch was confirmed to be
based on `v17.9.1`. Relevant overlapping upstream changes were reviewed in the
notification menu, application routes, permissions and locale files.

The OpenProject 17.9.1 test suite, Daily Report RSpec/frontend tests, blank
database migration, Linux image build and backup restore rehearsal have not yet
been run on this branch. Do not treat this source upgrade as a production-ready
image until those checks pass on Linux.
