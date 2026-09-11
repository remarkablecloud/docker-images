# Changelog: PrestaShop

All notable changes to the RemarkableCloud PrestaShop image. Newest first.

## [8.2.8-r1] - 2026-09-11

### Added
- Initial RemarkableCloud build of PrestaShop 8.2.8 (PHP 8.1, Apache), pinned to `prestashop/prestashop@sha256:fb50922a7a8dafdd5b824b35ab7b58fd9c4fb7cd189a3699b9527e2dfb8e8033` (Debian 12).
- Headless install from environment (`DB_*`, `PS_DOMAIN`), so no web installer step is needed.
- First-run wrapper generates a strong admin password and a randomized admin-folder name, persists both in the data volume, and prints the login and admin URL path once. A user-pinned `ADMIN_PASSWD` is honoured.
- Proxy-aware behind a TLS-terminating reverse proxy: `X-Forwarded-Proto: https` is mapped to HTTPS and `PS_ENABLE_SSL` is on, so the storefront serves without redirect loops.
- Static `/rc-health.txt` served directly by Apache for the container healthcheck, independent of PrestaShop routing.

### Security
- No default credentials: the upstream `prestashop_demo` admin password and the default `/admin` folder are both replaced with generated values on first run.
- Baseline build: no CVE fixes carried yet. Future entries note base-image bumps and any CVEs picked up.

### Notes
- Version chosen: PrestaShop 8.2.x (stable line). The current `latest` (9.1.x) headless install is broken upstream (installer asset step fails), so this image pins 8.2.8 per our "latest stable unless broken" policy.
- Upgrade model: PrestaShop populates its whole docroot into the data volume on first run and upgrades in-app (1-click upgrade). An image retag bumps the base OS and PHP; PrestaShop core updates come from the in-app updater.
