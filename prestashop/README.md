# PrestaShop

PrestaShop, an open source ecommerce platform, packaged by RemarkableCloud with a digest-pinned base, a headless install, and an admin password plus a randomized admin folder generated on first run so the store never ships with default credentials. It runs behind a TLS-terminating reverse proxy with a MariaDB database and a persistent data volume.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/prestashop:8.2.8-r1
```

## Quick start

A standalone stack (PrestaShop + MariaDB) is defined in [`docker-compose.yml`](./docker-compose.yml):

```bash
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
# then browse http://localhost:8094 ; the admin login + admin URL path are printed in
# `docker compose logs prestashop`
```

## More

Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** PrestaShop: OSL-3.0
