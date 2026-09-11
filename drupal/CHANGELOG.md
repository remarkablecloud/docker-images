# Changelog: Drupal

All notable changes to the RemarkableCloud Drupal image. Newest first.

## [11.4.6-r1] - 2026-09-11

### Added
- Initial RemarkableCloud build of Drupal 11.4.6 (PHP 8.5, Apache), pinned to `drupal@sha256:4249d58e94b052d5601499c7d1377433b5c9a8ad7b7b2d330368ce29181aca9c` (Debian 13).
- `drush` added at build for a headless first-boot install: on first run the wrapper waits for the database, runs `drush site:install` (standard profile) with a generated admin password, and prints the login once. A user-pinned `DRUPAL_ADMIN_PASSWORD` is honoured.
- Proxy-aware: `reverse_proxy` and `trusted_host_patterns` are written to `settings.php`, so Drupal serves behind a TLS-terminating reverse proxy with correct HTTPS URLs and no redirect loop.
- Static `/rc-health.txt` served directly by Apache for the container healthcheck, independent of Drupal routing.

### Security
- No default credentials: the admin password is generated on first run, never baked into an image layer.
- Retag-safe: Drupal core, contrib modules, and vendor libraries stay in the image; only `sites/default` (settings and uploaded files) is persisted, so an image retag updates the code without wiping content. Manage modules via composer (image rebuild) rather than the UI to keep upgrades clean.
- Baseline build: no CVE fixes carried yet. Future entries note base-image bumps and any CVEs picked up.
