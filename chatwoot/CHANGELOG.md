# Changelog: Chatwoot

All notable changes to the RemarkableCloud Chatwoot image. Newest first.

## [4.17.1-r1] - 2026-09-11

### Added
- Initial RemarkableCloud build of Chatwoot 4.17.1, pinned to `chatwoot/chatwoot@sha256:2116d958b52380ff3a609ad6b58db4a673b7733c31897771955b25350499ef06`.
- Chatwoot needs both a Puma web process and a Sidekiq worker; this image runs both in one container, supervised by the entrypoint: if either process exits, the container exits so the platform restarts it (no silent half-dead state).
- On first boot the entrypoint waits for PostgreSQL, runs `db:chatwoot_prepare` (loads the schema and seeds on an empty database, then always applies pending migrations, so the same image is also the upgrade path), then seeds the administrator.
- PostgreSQL via `POSTGRES_*` and Redis via `REDIS_URL` / `REDIS_PASSWORD`. HEALTHCHECK on `/health`.
- `SECRET_KEY_BASE` is generated once and persisted in the data volume so sessions and encrypted columns survive restarts.

### Security
- No public-first-admin: a fresh install's onboarding page would make the first visitor the super administrator. Instead we create a super administrator on first boot with a generated, complexity-compliant password (via Chatwoot's own `AccountBuilder`), clear the onboarding key, and bake `ENABLE_ACCOUNT_SIGNUP=false`, so a random visitor can neither claim the admin role nor self-register.
- No baked credentials; the admin password and `SECRET_KEY_BASE` live only in the instance's data volume, and the admin password is printed once to the log.
- Requires a PostgreSQL image carrying the `vector` extension (the schema enables it); the platform provisions it from `pgvector/pgvector`.
- Baseline build: no CVE fixes carried yet. Future entries note base-image bumps and any CVEs picked up.
