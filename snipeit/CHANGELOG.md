# Changelog: Snipe-IT

All notable changes to the RemarkableCloud Snipe-IT image. Newest first.

## [8.7.2-r1] - 2026-09-12

### Added
- Initial RemarkableCloud build of Snipe-IT 8.7.2, pinned to `snipe/snipe-it@sha256:18cc45da877ec5509e1fdb17b492db42e37d3ca3bc89d885d82e9c0ecdae1253` (Ubuntu 24.04, PHP 8.3, Apache with mod_php, serving HTTP on port 80).
- On first boot the entrypoint waits for the database, generates and persists a Laravel `APP_KEY`, then runs migrations. Upstream refuses to start without an `APP_KEY` and never generates one itself, so the key is created once and stored in the data volume so sessions and encrypted columns survive restarts.
- Migrations run automatically on every boot (about 470 on a fresh install), so the same image is also the upgrade path.
- Database connection via `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`, and `DB_CONNECTION` (default `mysql`). Production defaults are baked so a deploy cannot forget them: `SESSION_DRIVER=database`, `SECURE_COOKIES=true`, and `APP_TRUSTED_PROXIES=*`. Set `APP_URL` to the public https URL when running behind a proxy.
- Single data volume at `/var/lib/snipeit` holds uploads, private uploads, and the OAuth/Passport keys. The `.env` file is not persisted; configuration is env-driven.
- HEALTHCHECK on `/health`, which is unauthenticated and excepted from the setup middleware, returning `{"status":"ok"}` once the database is reachable.

### Security
- No public-first-admin: Snipe-IT's setup is a browser wizard where the first visitor becomes a superuser. Creating an admin alone does not close it. The `/setup` gate is `users>0 AND settings>0`, and the wizard POST has no user-count guard, so with no settings row an anonymous visitor could still mint a second superuser. On first boot, before Apache accepts a request, we create a generated superuser (username `admin`) AND write a settings row, which together close `/setup`.
- No baked credentials: the generated admin password and the `APP_KEY` live only in the instance's data volume, and the admin password is printed once to the container log.
- Digest-pinned base so each build is auditable and reproducible.
- Baseline build: no CVE fixes carried yet. Future entries note base-image bumps and any CVEs picked up.
