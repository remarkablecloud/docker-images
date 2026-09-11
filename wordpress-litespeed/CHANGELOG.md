# Changelog

All notable changes to the `ghcr.io/remarkablecloud/wordpress-litespeed` image are recorded here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and entries are newest
first. Each entry is one promoted build and doubles as the CVE-alert feed for this image, so it lists
the upstream WordPress version, the digest-pinned base image, and any security-relevant change.

> This image runs on LiteSpeed Web Server Enterprise, which is commercial software. It ships with no
> license key: it uses a 14-day LiteSpeed trial by default and requires a third-party LiteSpeed
> license for production (bring your own serial through `LSWS_SERIAL`).

## [6.3.6-r1] - 2026-09-10

Initial promoted build of WordPress on LiteSpeed Web Server Enterprise.

### Base and upstream
- WordPress 7.1 (latest stable at build time), downloaded into the docroot at
  `/var/www/vhosts/localhost/html`.
- Base image `litespeedtech/litespeed` (pinned by digest; the upstream tag is not part of the
  reference), digest-pinned to
  `sha256:454d6bafcfe7bb8d16fa3fa1e9cc0223bb0efacc967177b95e3c5078fa33a57f` (never `latest`).
- LiteSpeed Web Server Enterprise 6.3.6 with lsphp 8.4 (PHP 8.4) and wp-cli from the base.

### Added
- LiteSpeed Cache (full-page cache) and Redis Object Cache pre-baked at build time from wordpress.org
  and activated on first run. The exact bundled plugin versions are recorded in
  `wp-content/.rc-plugins` inside the image.
- `.htaccess` auto-load enabled in the LiteSpeed docker vhost template (`autoLoadHtaccess`), so
  WordPress permalinks and LiteSpeed Cache rewrite rules take effect.
- BYOL license handling: the entrypoint writes `LSWS_SERIAL` to `conf/serial.no` before LiteSpeed
  starts when a serial is provided; otherwise the base auto-fetches a 14-day trial key on first start
  (needs outbound internet). No serial is ever baked into the image.
- Idempotent first-run provisioner (`wp-setup.sh`, shared with the OpenLiteSpeed flavor) that writes
  `wp-config.php`, waits for the database, installs core when the site is empty, sets pretty
  permalinks, and enables the Redis object cache.
- Proxy-aware canonical URLs: `WP_HOME` and `WP_SITEURL` are derived per request from
  `X-Forwarded-Proto` and `X-Forwarded-Host`. No URL is baked into the image.
- Persistent `wp-content` volume seeded from the image on first mount, so uploads, plugins, and themes
  survive redeploys while core and the baked plugins stay in the image.
- Healthcheck gated on a provisioning marker (`/run/rc-provisioned`) plus a static health endpoint
  (`/rc-health.txt`), so the container reports healthy only after WordPress is installed and serving.

### Security and hardening
- Version disclosure off in PHP (`expose_php Off`); `display_errors` off with `log_errors` on.
- WordPress `DISALLOW_FILE_EDIT` set (no in-dashboard code editor); core auto-updates limited to minor
  releases; `WP_ENVIRONMENT_TYPE` set to `production`.
- Only the HTTP port (`80`) is exposed; TLS terminates at the reverse proxy. lsphp workers run as
  `nobody:nogroup`, not root.

### Known limitations
- The LiteSpeed WebAdmin console (`:7080`) still runs inside the container. It is not published through
  the platform, but tightening it further is a tracked follow-up.
- A trial license cannot serve a production site past 14 days; set `LSWS_SERIAL` for any production use.

[6.3.6-r1]: https://github.com/remarkablecloud/apps/tree/main/images/wordpress/litespeed-ent
