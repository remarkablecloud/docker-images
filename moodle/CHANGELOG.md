# Changelog: Moodle

All notable changes to the RemarkableCloud Moodle image. Newest first.

## [5.2.2-r1] - 2026-09-12

### Added
- Initial RemarkableCloud build of Moodle 5.2.2, built from the Moodle v5.2.2 source on a digest-pinned `php:8.4-apache` base (PHP 8.4, Apache mod_php, Debian 13, port 80). There is no clean official Moodle image (the Bitnami image is discontinued), so this is a from-source build (about 1.55 GB).
- Headless CLI install with a generated admin: on first boot the entrypoint waits for PostgreSQL, then runs `admin/cli/install_database.php` before Apache serves, so the operator is never made admin through the browser wizard. The admin login (username `admin`) and password are printed once to the container log and stored in `moodledata`.
- Docroot-on-volume: the Moodle code lives on a volume seeded from a baked copy, so UI-installed plugins and themes persist; an image upgrade syncs new code in place and runs `admin/cli/upgrade.php`.
- Env-driven `config.php` regenerated on each boot from `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASS`, and `MOODLE_WWWROOT` (includes `sslproxy` for a TLS-terminating reverse proxy).
- In-container cron daemon: Moodle requires cron for notifications, scheduled tasks, and search indexing.
- PHP tuned for Moodle (`max_input_vars=5000`, `memory_limit=256M`, and larger upload limits).
- Redirect-immune healthcheck: a static `/rc-health.txt` served from the `public/` docroot, touched only after install or upgrade completes. Moodle canonicalizes `/login` to `wwwroot`, so a plain login probe would redirect and defeat the check.

### Security
- No public-first-admin: the administrator is created by the headless CLI install with a generated password before the site is reachable, so the first visitor can never claim the admin role through the install wizard.
- No baked credentials: the admin password lives only in `moodledata` (printed once to the log), and the encryption secrets under `moodledata/secret` must persist with that volume. Note there is no Laravel-style APP_KEY and, for new installs, no site-wide password salt.
- Configured for PostgreSQL 17 (Moodle 5.2 requires PostgreSQL 17 or newer); the platform provisions Postgres 17.
- Digest-pinned base for reproducible, auditable rebuilds.
- Baseline build: no CVE fixes carried yet. Future entries note base-image bumps and any CVEs picked up.
