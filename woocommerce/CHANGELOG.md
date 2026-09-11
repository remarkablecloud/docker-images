# Changelog: WooCommerce

All notable changes to the RemarkableCloud WooCommerce image. Newest first.

## [11.1.0-r1] - 2026-09-11

### Added
- Initial RemarkableCloud build: WooCommerce 11.1.0 on our WordPress + OpenLiteSpeed image, derived from `ghcr.io/remarkablecloud/wordpress-ols:7.1-r2` (PHP 8.5).
- WooCommerce is baked at build time into the wp-content seed and auto-activated on first run (via `WP_EXTRA_PLUGINS`) before the readiness marker, so traffic is only routed once the store is fully set up (WooCommerce pages and database tables created).
- Inherits from the base image: LiteSpeed Cache (page cache), Redis object cache, proxy-aware canonical URLs behind a TLS-terminating reverse proxy, non-root PHP workers, a generated admin password on first run, and a healthcheck that stays unhealthy until provisioning completes.

### Security
- No baked credentials: the admin password is generated on first run (printed once to the container log) or supplied via `WP_ADMIN_PASSWORD`.
- Core code and baked plugins live in the image; only `wp-content` is persisted, so a retag upgrades WordPress, WooCommerce, and our plugins without wiping uploads.
- Baseline build: no CVE fixes carried yet. Future entries note base-image bumps and any CVEs picked up.
