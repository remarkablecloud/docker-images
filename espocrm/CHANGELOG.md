# Changelog: EspoCRM

All notable changes to the RemarkableCloud EspoCRM image. Newest first.

## [10.0.8-r1] - 2026-09-11

### Added
- Initial RemarkableCloud build of EspoCRM 10.0.8 (PHP 8.4, Apache), pinned to `espocrm/espocrm@sha256:817f2b063de2c9dc2655fedbf1960af33c9b04e84d61a4b95f243e8e9189de69` (Debian 13).
- Headless install from environment (`ESPOCRM_DATABASE_*`, `ESPOCRM_ADMIN_*`, `ESPOCRM_SITE_URL`), so no web installer step is needed.
- First-boot wrapper sets a strong generated admin password before the install runs, persists it in the data volume for install-retry, and prints it once. A user-pinned `ESPOCRM_ADMIN_PASSWORD` is honoured and not logged.
- In-container job daemon (scheduled jobs, email fetching, workflows, notifications) supervised alongside the web server, so a single container is fully functional.
- HEALTHCHECK on `/`; OCI provenance labels; `image.source` points at this repo.

### Security
- No default credentials: the upstream `admin` / `password` default is replaced with a generated password at first install, before the instance is exposed.
- Persistent volumes cover `data/`, `custom/`, and `client/custom/` only, so an image retag upgrades core code without wiping customer customizations or uploads.
- Baseline build: no CVE fixes carried yet. Future entries note base-image bumps and any CVEs picked up.
