# Joomla

Joomla CMS (Joomla 5 on PHP 8.3), packaged by RemarkableCloud with a digest-pinned base, a headless env-driven install, and an admin password auto-generated on first run and printed to the container log. It runs behind a TLS-terminating reverse proxy with MariaDB and a persistent /var/www/html volume for site content.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/joomla:5-r1
```

## Quick start

A standalone stack (Joomla + MariaDB) is defined in [`docker-compose.yml`](./docker-compose.yml):

```bash
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
# then browse http://localhost:8087 ; the admin password is printed in `docker compose logs`
```

## More

Full documentation (compose walkthrough, environment reference, hardening, backup, and upgrade guidance) is authored in [`site.md`](./site.md). Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** Joomla: GPL-2.0-or-later
