# WooCommerce on OpenLiteSpeed (`woocommerce`)

WooCommerce on WordPress and OpenLiteSpeed with PHP 8.5, packaged by RemarkableCloud: our hardened WordPress image with WooCommerce baked in and activated on first run, plus LiteSpeed Cache and a Redis object cache. It is proxy-aware for running behind a TLS-terminating reverse proxy, generates the admin password on first run, and stays unhealthy until the store is fully provisioned.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/woocommerce:11.1.0-r1
```

## Quick start

A standalone stack (WooCommerce + MariaDB + Redis) is defined in [`docker-compose.yml`](./docker-compose.yml):

```bash
REDIS_PASSWORD=$(openssl rand -hex 16) DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
# then browse http://localhost:8092 ; the admin login is printed in `docker compose logs woocommerce`
```

## More

Full documentation (compose walkthrough, environment reference, hardening, backup, and upgrade guidance) is authored in [`site.md`](./site.md). Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** WooCommerce: GPL-3.0-or-later; WordPress: GPLv2-or-later (OpenLiteSpeed server: GPLv3)
