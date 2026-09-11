# WordPress on LiteSpeed Enterprise (`wordpress-litespeed`)

WordPress on LiteSpeed Web Server Enterprise with PHP 8.4, packaged by RemarkableCloud with hardened defaults and LiteSpeed Cache plus a Redis object cache wired in. It runs on a 14-day LiteSpeed trial by default and requires a third-party LiteSpeed license for production (bring your own serial through `LSWS_SERIAL`), with proxy-aware canonical URLs for running behind a TLS-terminating reverse proxy and a healthcheck that stays unhealthy until WordPress is fully provisioned.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/wordpress-litespeed:6.3.6-r1
```

## Quick start

A complete standalone stack (WordPress on LiteSpeed Enterprise, MariaDB, and Redis) is defined in
[`docker-compose.yml`](./docker-compose.yml) in this directory:

```bash
REDIS_PASSWORD=$(openssl rand -hex 16) DB_PASSWORD=$(openssl rand -hex 16) \
WP_ADMIN_PASSWORD=$(openssl rand -hex 12) docker compose up -d
# then browse http://localhost:8085
```

It starts on the 14-day LiteSpeed trial by default; set `LSWS_SERIAL` to bring your own LiteSpeed
Enterprise license for production. TLS is terminated by a reverse proxy; the image serves plain HTTP
on port 80 and derives its canonical URL from the `X-Forwarded-Proto` and `X-Forwarded-Host` headers.

## More

Full documentation (licensing, compose walkthrough, environment reference, hardening, backup, and
upgrade guidance) lives on the RemarkableCloud site and is authored in [`site.md`](./site.md). The
build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** WordPress: GPLv2-or-later (LiteSpeed Enterprise: commercial, bring your own license)
