# Mautic

Mautic, open source marketing automation (email campaigns, landing pages, contacts, segments, and forms), packaged by RemarkableCloud as a single container: Apache with mod_php serves in the foreground while a background cron loop advances segments and campaigns, so no separate cron or worker container is needed. The install runs headless with a generated administrator before Apache serves its first request, so the install wizard is never reachable by a visitor. A digest-pinned base, a persisted secret key, and database migrations on later boots round it out.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/mautic:5.2.11-r1
```

## Quick start

A standalone stack (Mautic + MySQL) is defined in [`docker-compose.yml`](./docker-compose.yml):

```bash
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
# first boot runs the install (about 1 to 2 min); the admin login is printed in
# `docker compose logs mautic`, then browse http://localhost:8097
```

## More

Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** Mautic: GPL-2.0-or-later.
