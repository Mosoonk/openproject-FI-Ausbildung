# Daily Report production-readiness record

Date: 2026-10-08

Target: the native Daily Report fork based on exact OpenProject `v17.8.0`,
deployed with Docker Compose on Linux (Intel i3-8100, 16 GB RAM).

## Verified

- Focused Daily Report RSpec suite: 16 examples, 0 failures.
- RuboCop passed for all 14 Daily Report Ruby files.
- Focused frontend ESLint passed; the wider touched-file run still reports four
  pre-existing `wp-tabs.component.ts` findings.
- Production Angular asset compilation and the `slim` Docker target succeeded.
- Candidate image: `openproject-daily-report:17.8.0-dr.1-candidate`.
- Local image ID: `sha256:991346cf88ec8ca76130d2ebfb306a82cf53950d225d8cb40077e0ade2a4a45f`.
- A blank PostgreSQL 17 database completed schema initialization, migrations,
  and seeding through `docker/prod/seeder`.
- The blank database contains all four expected `daily_report_*` tables.
- Web, worker, cron, PostgreSQL, and Memcached reached their configured healthy
  or running state in the isolated Compose smoke stack.

The image build is an intentional adaptation of the `v17.8.0` source: it uses
the repository's production `slim` target and keeps Hocuspocus disabled in the
initial IP-only deployment. Daily Report itself does not require Hocuspocus.

## Must be closed before production approval

1. Add TLS. Plain HTTP exposes passwords, sessions, API tokens, report text,
   and attachments. Until then, access must at least be restricted by host and
   network firewalls; this is mitigation, not resolution.
2. Publish the tested image under an immutable private-registry tag/digest and
   verify that the Linux server can authenticate and pull it. Do not deploy
   `latest` or build the application on the production host.
3. Run the Compose smoke test on the actual Linux host. During the local WSL
   run, the complete Docker engine repeatedly restarted, resetting every
   container at once. Internal container health returned HTTP 200, but the
   published-port request was reset during those engine restarts.
4. Restore a representative OpenProject backup into an isolated copy of this
   stack, run migrations, and verify Daily Report permissions, create/read,
   corrections, notifications, attachments, worker jobs, and API-token reads.
5. Create and test an off-host backup/restore procedure covering PostgreSQL,
   `/var/openproject/assets`, and the persistent `SECRET_KEY_BASE`.
6. Review the frontend dependency audit findings reported during the image
   build (1 low, 15 moderate, 22 high, 3 critical). Do not apply an unreviewed
   `npm audit fix` to the pinned upstream dependency tree.
7. Configure monitoring for disk, memory, PostgreSQL, container restarts,
   health checks, failed background jobs, and backup age.

## Capacity notes

Four CPU cores and 16 GB RAM are sufficient for a small installation, subject
to measured concurrency, attachment volume, and SSD capacity. Build images in
CI: building the production frontend while the development stack was running
exhausted the current WSL allocation. Runtime and image-build requirements are
different and must not be conflated.
