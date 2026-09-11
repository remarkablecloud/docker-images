# RemarkableCloud Nextcloud

Nextcloud is an open source platform for file sync and share, calendar,
contacts, and team collaboration that you host yourself. This is the
RemarkableCloud build of Nextcloud 34, with reverse-proxy configuration baked
in, Redis and APCu caching wired, PHP tuned, an automatic first-run admin
password, and a status.php healthcheck, ready to run behind Traefik with an
external MariaDB and Redis.

## Pull

```
docker pull ghcr.io/remarkablecloud/nextcloud:34.0.3-r1
```

## Quick start

Run the standalone stack (Nextcloud plus MariaDB plus Redis plus a data volume)
with [`docker-compose.yml`](./docker-compose.yml):
`REDIS_PASSWORD=$(openssl rand -hex 16) DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d`
then open `http://localhost:8082`. The admin password is generated on first run
and printed once to the container log.

## Learn more

Full production guide (compose walkthrough, environment reference, hardening,
backups, and upgrades) lives on the RemarkableCloud App Platform page for
Nextcloud: https://remarkablecloud.com/apps/nextcloud. Version history and
security notes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** Nextcloud: AGPL-3.0-or-later
