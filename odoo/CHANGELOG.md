# Changelog: Odoo

All notable changes to the RemarkableCloud Odoo image. Newest first.

## [18.0-r1] - 2026-09-11

### Added
- Initial RemarkableCloud build of Odoo 18.0 Community (Python 3.12, Ubuntu 24.04), pinned to `odoo:18@sha256:c01e5bc381f087a3be2800d65cff8ad51ab0709dc54c3b81cd9b0d6c9b3a4d77`.
- PostgreSQL backend via `HOST`/`PORT`/`USER`/`PASSWORD` (the upstream entrypoint waits for the database).
- First-run wrapper generates a strong master password (`admin_passwd`), persists it in the `/var/lib/odoo` filestore volume, writes it into a config Odoo reads (`ODOO_RC`), and prints it once.
- HEALTHCHECK on `/web/health`. The filestore (attachments, sessions) persists in `/var/lib/odoo`.

### Security
- No insecure default master password: the database manager is protected by a generated 40-hex master password, never the upstream default `admin`, so only the customer can create or drop databases.
- No credentials baked into an image layer.
- The customer creates their database and admin login through the manager on first access (Odoo's standard onboarding, where apps/country/language are chosen), gated by the master password.
- Baseline build: no CVE fixes carried yet. Future entries note base-image bumps and any CVEs picked up.
