# Changelog: Joomla

All notable changes to the RemarkableCloud Joomla image. Newest first.

## [5-r1] - 2026-09-11

### Added
- Initial RemarkableCloud build of Joomla 5 (PHP 8.3), pinned to `joomla:5-php8.3-apache@sha256:55a35a9e0025624a55752981f636512f0fc43632bfec860e6301b152043dcfb7` (Debian 13).
- Headless install from environment (JOOMLA_DB_* and JOOMLA_ADMIN_*), so no web installer step is needed.
- Entrypoint wrapper generates a strong admin password on first install when none is provided and prints it once to the container log.
- HEALTHCHECK on `/`; OCI provenance labels; `image.source` points at this repo.

### Security
- No credentials baked into the image; the admin password is generated at first install or supplied via `JOOMLA_ADMIN_PASSWORD`.
- Baseline build: no CVE fixes carried yet. Future entries note base-image bumps and any CVEs picked up.
