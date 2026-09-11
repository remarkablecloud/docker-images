# Changelog: BookStack

All notable changes to the RemarkableCloud BookStack image. Newest first.

## [26.05.4-r1] - 2026-09-11

### Added
- Initial RemarkableCloud build of BookStack v26.05.4, pinned to `lscr.io/linuxserver/bookstack@sha256:ec33b8ad7ab57305462e73f2f9bd091a3828ac9f62e7eaa4f4fac592b9310303` (Alpine 3.24, PHP 8.5).
- First-boot wrapper generates a per-instance Laravel APP_KEY, persists it in the `/config` volume, and exports it before the upstream init builds `.env`. A platform- or user-supplied `APP_KEY` takes precedence and is remembered.
- First-boot rotation of the upstream default admin (`admin@admin.com` / `password`): a strong password is generated, applied, and printed once to the container log. The password can be pinned with `RC_ADMIN_PASSWORD` and the email overridden with `RC_ADMIN_EMAIL`. It runs exactly once (marker in `/config`), so a later password change is never clobbered.
- HEALTHCHECK on `/status`; OCI provenance labels; `image.source` points at this repo.

### Security
- No shared or baked APP_KEY: each instance gets a unique key on first boot, stored only in its own data volume, so encrypted data cannot be read across instances.
- No usable default credentials: the well-known `admin@admin.com` / `password` account seeded by upstream is rotated to a generated password on first boot, before the instance is exposed.
- Baseline build: no CVE fixes carried yet. Future entries note base-image bumps and any CVEs picked up.
