# WordPress on OpenLiteSpeed (`wordpress-ols`)

WordPress on OpenLiteSpeed with PHP 8.5, packaged by RemarkableCloud with hardened defaults for production. It comes with LiteSpeed Cache and a Redis object cache wired in, proxy-aware canonical URLs for running behind a TLS-terminating reverse proxy, non-root PHP workers, and a healthcheck that stays unhealthy until WordPress is fully provisioned.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/wordpress-ols:7.1-r2
```

## Quick start

A complete standalone stack (WordPress on OpenLiteSpeed, MariaDB, and Redis) is defined in
[`docker-compose.yml`](./docker-compose.yml) in this directory:

```bash
REDIS_PASSWORD=$(openssl rand -hex 16) DB_PASSWORD=$(openssl rand -hex 16) \
WP_ADMIN_PASSWORD=$(openssl rand -hex 12) docker compose up -d
# then browse http://localhost:8080
```

TLS is terminated by a reverse proxy in production; the image serves plain HTTP on port 80 and derives
its canonical URL from the `X-Forwarded-Proto` and `X-Forwarded-Host` headers.

## More

Full documentation (compose walkthrough, environment reference, hardening, backup, and upgrade
guidance) lives on the RemarkableCloud site and is authored in [`site.md`](./site.md). The build
history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** WordPress: GPLv2-or-later (OpenLiteSpeed server: GPLv3)
