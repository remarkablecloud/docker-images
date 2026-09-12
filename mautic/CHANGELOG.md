# Changelog: Mautic

All notable changes to the RemarkableCloud Mautic image. Newest first.

## [5.2.11-r1] - 2026-09-12

### Added
- Initial RemarkableCloud build of Mautic 5.2.11, pinned by digest to `mautic/mautic:5.2.11-apache` (Debian 12, PHP 8.2, Apache with mod_php, port 80).
- Single-container operation: Apache serves in the foreground while a background cron loop advances segments and campaigns. Mautic requires cron, and upstream normally ships separate web, cron, and worker containers; this image needs none of the extras. The message bus defaults to `sync://`, so queued work runs in process (no Redis required; the cache is on the filesystem).
- Database on MySQL or MariaDB via `MAUTIC_DB_HOST`, `MAUTIC_DB_PORT`, `MAUTIC_DB_NAME`, `MAUTIC_DB_USER`, and `MAUTIC_DB_PASSWORD`. `MAUTIC_SITE_URL` sets the public HTTPS URL; set `MAUTIC_TRUSTED_PROXIES` when running behind a reverse proxy.
- On later boots the entrypoint applies any pending database migrations, so the same image is also the upgrade path.
- HEALTHCHECK on `/s/login` gated on an exact HTTP 200 (before the install completes that path 302-redirects to `/installer`).

### Security
- No public install wizard: a headless install with a generated administrator runs before Apache serves a request, so `/installer` (the only anonymous exposure; Mautic core has no public self-registration) is never reachable by a visitor. The generated admin (username `admin`) login and password are printed once to the log and stored in the config volume.
- A stable `secret_key` is generated on first boot and persisted in the config volume; it also encrypts stored integration credentials.
- No baked credentials; the admin password and `secret_key` live only in the instance's config volume.
- Digest-pinned base image for reproducible, auditable rebuilds.
- Baseline build: no CVE fixes carried yet. Future entries note base-image bumps and any CVEs picked up.
