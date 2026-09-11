# Changelog

All notable changes to the `ghcr.io/remarkablecloud/wordpress-nginx` image are recorded here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and entries are newest
first. Each entry is one promoted build and doubles as the CVE-alert feed for this image, so it lists
the upstream WordPress version, the digest-pinned base image, and any security-relevant change.

## [7.1-r1] - 2026-09-10

Initial promoted build of WordPress on Nginx and PHP-FPM.

### Base and upstream
- WordPress 7.1 (latest stable at build time), from the official WordPress core stashed at
  `/usr/src/wordpress` in the base image and copied into the docroot on first run.
- Base image `wordpress:php8.5-fpm`, digest-pinned to
  `sha256:7a016a9049c02a11fb81705bfe0c6950d6626303863bbb0242c20c04fec8a173` (never `latest`).
- Debian 13 with PHP 8.5.10 (php-fpm).

### Added
- Nginx (nginx-light) added on top of PHP-FPM, with both processes supervised by supervisord in a
  single container (php-fpm on `127.0.0.1:9000`, Nginx on port 80).
- fastcgi micro-cache (full-page cache) configured in Nginx, keyed per scheme, method, host, and URI,
  bypassed for POST requests, query strings, admin and dynamic paths, and logged-in cookies. Cache
  purge is handled by the Nginx Helper plugin.
- Brotli compression (`libnginx-mod-http-brotli-*`) alongside gzip, for text, CSS, JavaScript, JSON,
  SVG, and woff2 assets.
- Redis Object Cache and Nginx Helper plugins pre-baked at build time from wordpress.org, activated
  on first run. The exact bundled plugin versions are recorded in `wp-content/.rc-plugins` inside the
  image.
- php-redis extension built from PECL and enabled; wp-cli included.
- Idempotent first-run provisioner (`wp-setup.sh`) that copies core into the docroot, writes
  `wp-config.php`, waits for the database, installs core when the site is empty, sets pretty
  permalinks, and enables the Redis object cache.
- Proxy-aware canonical URLs: `WP_HOME` and `WP_SITEURL` are derived per request from
  `X-Forwarded-Proto` and `X-Forwarded-Host`; Nginx trusts the private-range proxy for the real
  client IP via `X-Forwarded-For`. No URL is baked into the image.
- Persistent `wp-content` volume seeded from the image on first mount, so uploads, plugins, and themes
  survive redeploys while core and the baked plugins stay in the image.
- Healthcheck gated on a provisioning marker (`/run/rc-provisioned`) plus a static health endpoint
  (`/rc-health.txt`) served directly by Nginx, so the container reports healthy only after WordPress
  is installed and serving.

### Security and hardening
- `server_tokens off` in Nginx and `expose_php Off` in PHP; `display_errors` off with `log_errors` on.
- Direct access to `wp-config.php` and `xmlrpc.php` denied; dotfiles denied except `/.well-known`;
  PHP execution denied inside `uploads`, `files`, and `wp-content`.
- WordPress `DISALLOW_FILE_EDIT` set (no in-dashboard code editor); core auto-updates limited to minor
  releases; `WP_ENVIRONMENT_TYPE` set to `production`.
- Nginx and php-fpm workers run as `www-data`, not root.

[7.1-r1]: https://github.com/remarkablecloud/apps/tree/main/images/wordpress/nginx
