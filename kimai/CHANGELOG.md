# Changelog: Kimai

All notable changes to the RemarkableCloud Kimai image. Newest first.

## [2.66.0-r1] - 2026-09-11

### Added
- Initial RemarkableCloud build of Kimai 2.66.0 (PHP 8.3, Apache), pinned to `kimai/kimai2@sha256:d6747832bafc63b69f95d505471e43430f55f2e8a5ca19d094a166c5c2da2239` (Debian 12).
- Env-driven install: the upstream entrypoint waits for the database, runs migrations, and creates the admin from `ADMINMAIL` / `ADMINPASS`.
- First-run wrapper generates a strong admin password, persists it in the data volume, and prints the login once; a user-pinned `ADMINPASS` is honoured. It also builds `DATABASE_URL` from separate parts with the password URL-encoded, so special characters cannot break the connection string.
- Proxy-aware: `TRUSTED_PROXIES` covers private networks, so Kimai honors `X-Forwarded-Proto` behind a TLS-terminating reverse proxy and generates https URLs. Serves on port `8001`.

### Security
- No default credentials: the admin password is generated on first run.
- `APP_SECRET` is auto-generated and persisted in `var/data` by the upstream entrypoint (never the public default).
- Retag-safe: the application stays in the image; only `var/data` (APP_SECRET and uploaded data) is persisted, so an image retag updates the code without wiping content.
- Baseline build: no CVE fixes carried yet. Future entries note base-image bumps and any CVEs picked up.
