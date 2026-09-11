# Changelog

All notable changes to the `ghcr.io/remarkablecloud/wordpress-ols` image are recorded here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and entries are newest
first. Each entry is one promoted build and doubles as the CVE-alert feed for this image, so it lists
the upstream WordPress version, the digest-pinned base image, and any security-relevant change.

## [7.1-r2] - 2026-09-10

Initial promoted build of WordPress on OpenLiteSpeed.

### Base and upstream
- WordPress 7.1 (latest stable at build time), baked into the image at `/var/www/vhosts/wordpress/html`.
- Base image `litespeedtech/openlitespeed:1.8.4-lsphp85`, digest-pinned to
  `sha256:61ba9fe3e140d07fe3462e85946581c614999fd08950acc54b0bfe0f0fb9b786` (never `latest`).
- OpenLiteSpeed 1.8.4 with lsphp 8.5 (PHP 8.5.0, GA November 2025), including redis, imagick, intl,
  gd, mysqli, and opcache extensions plus wp-cli from the base.

### Added
- LiteSpeed Cache (full-page cache) and Redis Object Cache pre-baked at build time from wordpress.org,
  so there is no order-time download. The exact bundled plugin versions are recorded in
  `wp-content/.rc-plugins` inside the image.
- Idempotent first-run provisioner (`wp-setup.sh`) that writes `wp-config.php`, waits for the database,
  installs core when the site is empty, sets pretty permalinks, activates the pre-baked plugins, and
  enables the Redis object cache.
- Proxy-aware canonical URLs: `WP_HOME` and `WP_SITEURL` are derived per request from
  `X-Forwarded-Proto` and `X-Forwarded-Host`, so the site follows the customer domain when it runs
  behind a TLS-terminating reverse proxy (Traefik). No URL is baked into the image.
- Persistent `wp-content` volume seeded from the image on first mount, so uploads, plugins, and themes
  survive redeploys while core and the baked plugins stay in the image.
- Healthcheck gated on a provisioning marker (`/run/rc-provisioned`) plus a static health endpoint
  (`/rc-health.txt`), so the container reports healthy only after WordPress is installed and serving.
  The probe hits a static file, so it never primes the page cache with a wrong canonical homepage.

### Security and hardening
- OpenLiteSpeed WebAdmin console (`:7080`) disabled (`disableWebAdmin 1`); no admin port and no
  default-password surface.
- Demo listeners and vhosts removed (the `:8088` Default listener, the `:443` HTTPS listener, and the
  Example vhost); a single plain-HTTP listener on `:80` serves the WordPress vhost, with TLS terminated
  at the proxy.
- Version disclosure off (`showVersionNumber 0` in OpenLiteSpeed, `expose_php Off` in PHP);
  `display_errors` off with `log_errors` on.
- WordPress `DISALLOW_FILE_EDIT` set (no in-dashboard code editor); core auto-updates limited to minor
  releases; `WP_ENVIRONMENT_TYPE` set to `production`.
- Direct access to `wp-config.php` and `xmlrpc.php` denied at the server edge.
- lsphp workers run as `nobody:nogroup`, not root.

[7.1-r2]: https://github.com/remarkablecloud/apps/tree/main/images/wordpress/ols
