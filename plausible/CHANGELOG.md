# Changelog: Plausible

All notable changes to the RemarkableCloud Plausible image. Newest first.

## [3.2.1-r1] - 2026-09-12

### Added
- Initial RemarkableCloud build of Plausible Community Edition 3.2.1, pinned to `ghcr.io/plausible/community-edition:v3.2.1@sha256:33e60bfb40f2df5da00f8753b76fad04f67dba3abe6d73eb516e440e3fb62985`.
- Plausible needs two datastores: PostgreSQL for application data (via `DATABASE_URL`) and ClickHouse for analytics events (via `CLICKHOUSE_DATABASE_URL`, over ClickHouse's HTTP interface on port 8123, with the database name as the URL path). This image creates both databases and runs migrations on first boot (Plausible's own run command does neither), idempotent, so the same image is also the upgrade path.
- `BASE_URL` must be the public https URL. Optional SMTP relay via `SMTP_HOST_ADDR` and `SMTP_HOST_PORT` for invitations and password resets.
- HEALTHCHECK on `/api/health` (unauthenticated; returns 200 only when PostgreSQL and ClickHouse are both reachable and caches are warm).
- `SECRET_KEY_BASE` is generated once and persisted in the `/var/lib/plausible` data volume so cookies, sessions, and derived keys survive restarts.

### Security
- No public-first-owner: Plausible CE v3 removed the `ADMIN_USER_*` env bootstrap, and its first-launch flow makes the first visitor the owner. Instead we insert a generated admin (owner) directly on first boot, mirroring the real registration path, before the app serves, and bake `DISABLE_REGISTRATION=invite_only` so outsiders cannot self-register afterward.
- No baked credentials; the admin email, the admin password, and `SECRET_KEY_BASE` live only in the instance's data volume, and the admin login is printed once to the log.
- Runs as a non-root user (uid 999) and listens on port 8000; TLS is terminated upstream by the reverse proxy.
- Digest-pinned base for reproducible, auditable rebuilds.
- Baseline build: no CVE fixes carried yet. Future entries note base-image bumps and any CVEs picked up.
