# EspoCRM

EspoCRM, an open source customer relationship management platform, packaged by RemarkableCloud with a digest-pinned base, a headless env-driven install, and an admin password generated on first install and printed to the container log. It runs behind a TLS-terminating reverse proxy with a MariaDB database, persistent data volumes, and the job daemon running in-container for scheduled jobs and email.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/espocrm:10.0.8-r1
```

## Quick start

A standalone stack (EspoCRM + MariaDB) is defined in [`docker-compose.yml`](./docker-compose.yml):

```bash
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
# then browse http://localhost:8091 ; the admin login is printed in `docker compose logs espocrm`
```

## More

Full documentation (compose walkthrough, environment reference, hardening, backup, and upgrade guidance) is authored in [`site.md`](./site.md). Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** EspoCRM: GPL-3.0-only
