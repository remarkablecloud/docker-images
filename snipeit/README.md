# Snipe-IT

Snipe-IT, open source IT asset management (track hardware, licenses, accessories, and consumables), packaged by RemarkableCloud with a digest-pinned base, a persisted Laravel `APP_KEY`, and a generated superuser created on first boot. Because we also write a settings row on first boot, Snipe-IT's `/setup` wizard is closed before Apache ever serves a request, so the first visitor can never claim the admin role. The app runs under Apache with mod_php and expects an external MySQL/MariaDB database behind a TLS-terminating reverse proxy.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/snipeit:8.7.2-r1
```

## Quick start

A standalone stack (Snipe-IT + MySQL) is defined in [`docker-compose.yml`](./docker-compose.yml):

```bash
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
# first boot runs ~470 migrations and seeds (about one to two minutes); the admin login is printed
# once in `docker compose logs snipeit`, then browse http://localhost:8098
```

## More

Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** Snipe-IT: GNU AGPL-3.0.
