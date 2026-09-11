# BookStack

BookStack, a self-hosted wiki and documentation platform, packaged by RemarkableCloud with a digest-pinned base, a per-instance Laravel APP_KEY generated on first boot, and the upstream default admin credentials rotated to a generated password so the instance never ships with a known login. It runs behind a TLS-terminating reverse proxy with a MariaDB database and a persistent /config volume for uploads and settings.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/bookstack:26.05.4-r1
```

## Quick start

A standalone stack (BookStack + MariaDB) is defined in [`docker-compose.yml`](./docker-compose.yml):

```bash
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
# then browse http://localhost:8088 ; the admin login is printed in `docker compose logs bookstack`
```

## More

Full documentation (compose walkthrough, environment reference, hardening, backup, and upgrade guidance) is authored in [`site.md`](./site.md). Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** BookStack: MIT
