# Daily Report production deployment

This Compose stack runs the customized OpenProject 17.8.0 image. It is
separate from the repository root development stack and must not be pointed at
the development database or volumes.

## Important security limitation

The current configuration publishes plain HTTP because the target environment
was specified as IP-only without TLS. Login cookies, API tokens, report text,
and attachments can therefore be intercepted on the network. Limit access at
the firewall/VLAN and add TLS (an IP-address certificate or an internal CA is
enough) before treating this as an approved production deployment.

Collaborative editing is disabled until a reverse proxy can expose its secure
WebSocket endpoint. Daily Report does not depend on collaborative editing.

## First start

1. Install Docker Engine with the Compose plugin on the Linux host.
2. Copy `deploy/production` to the host and create `.env` from `.env.example`.
3. Replace the example IP and every placeholder secret. Generate secrets, for
   example, with `openssl rand -hex 32` and `openssl rand -hex 64`.
4. Make the exact custom image tag available on the host (prefer a private
   registry). Never use `latest` for this fork.
5. Validate and start:

   ```sh
   docker compose --env-file .env config --quiet
   # Required when OPENPROJECT_IMAGE points to a registry image:
   docker compose --env-file .env pull
   docker compose --env-file .env up -d
   docker compose --env-file .env ps
   docker compose --env-file .env logs --tail=100 seeder web worker
   ```

The `seeder` service runs schema loading/migrations and seeds before `web`,
`worker`, and `cron` start. Never run two seeders against the same database.

## Backup before every update

Stop application writes, then back up both PostgreSQL and attachments. Keep
the backup outside Docker volumes and test its restoration regularly.

```sh
docker compose --env-file .env stop web worker cron
docker compose --env-file .env exec -T db \
  pg_dump -U openproject -d openproject -Fc > openproject.dump
docker run --rm -v openproject-daily-report_assets:/source:ro \
  -v "$PWD":/backup alpine \
  tar -C /source -czf /backup/openproject-assets.tar.gz .
docker compose --env-file .env start web worker cron
```

Also retain the `.env` file securely; `SECRET_KEY_BASE` must survive updates.

## Updating the fork

Build and test a new immutable image tag in CI or on a build host, not on the
production server. Back up, change only `OPENPROJECT_IMAGE`, pull the image,
and let the one-shot seeder finish before the application restarts:

```sh
docker compose --env-file .env pull
docker compose --env-file .env up seeder
docker compose --env-file .env up -d web worker cron
docker compose --env-file .env ps
```

If validation fails, stop and restore both the database and attachments from
the matching backup. Rolling an image back after a database migration is not
by itself a safe rollback.

For upstream OpenProject updates, create an update branch from the current
Daily Report branch, merge the exact upstream release tag, resolve conflicts,
run the complete Daily Report tests and a blank-database migration test, then
merge through a reviewed pull request. Keep the feature commits separate from
upstream merge commits so the customization remains auditable.
