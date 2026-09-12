# Drupal

Drupal, an open source content management system, packaged by RemarkableCloud with a digest-pinned base, a headless install via drush, and an admin password generated on first run. It runs behind a TLS-terminating reverse proxy with a MariaDB database; Drupal core and modules stay in the image while settings and uploaded files persist in a volume, so an image update refreshes the platform without touching your content.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/drupal:11.4.6-r1
```

## Quick start

A standalone stack (Drupal + MariaDB) is defined in [`docker-compose.yml`](./docker-compose.yml):

```bash
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
# then browse http://localhost:8097 ; the admin login is printed in `docker compose logs drupal`
```

## More

Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** Drupal: GPL-2.0-or-later
