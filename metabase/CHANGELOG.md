# Changelog: Metabase

All notable changes to the RemarkableCloud Metabase image. Newest first.

## [0.63.17.2-r1] - 2026-09-12

### Added
- Initial RemarkableCloud build of Metabase 0.63.17.2 (the open source OSS edition, not Enterprise), pinned to `metabase/metabase:v0.63.17.2@sha256:5f2ace3426bc4fa9259d6ec68dacae0023c302e8e812ee7f54fce9f6942b6874`.
- Metabase stores its own state in an application database; this image bakes `MB_DB_TYPE=postgres` and reads `MB_DB_HOST`, `MB_DB_PORT`, `MB_DB_DBNAME`, `MB_DB_USER`, and `MB_DB_PASS`. With external PostgreSQL the container is otherwise stateless.
- `JAVA_OPTS=-XX:MaxRAMPercentage=70` so the JVM heap scales to the container's memory limit instead of a fixed size that fights plan sizing.
- HEALTHCHECK on `/api/health` (unauthenticated; returns `{"status":"ok"}` when ready, `503` while the app database migrates on first boot).
- A small `/rc-data` volume holds the generated encryption key and the generated admin password; all real state lives in PostgreSQL.

### Security
- No public-first-admin: Metabase OSS has no env-based admin creation and exposes a setup token on an unauthenticated endpoint until setup is completed, so the first visitor would otherwise become the administrator. Once the app is healthy the entrypoint reads that token and claims setup with a generated admin (email and password printed once to the log, stored in the `/rc-data` volume), before the platform hands the URL to the customer.
- `MB_ENCRYPTION_SECRET_KEY` is generated once and persisted in the `/rc-data` volume, so the credentials of every data source Metabase stores are encrypted at rest and stable across restarts. Without it those credentials would be stored in plaintext.
- No baked credentials; the encryption key and the admin password live only in the instance's `/rc-data` volume, and the admin password is printed once to the log.
- Digest-pinned base for reproducible, auditable rebuilds.
- Baseline build: no CVE fixes carried yet. Future entries note base-image bumps and any CVEs picked up.
