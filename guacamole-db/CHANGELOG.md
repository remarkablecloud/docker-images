# Changelog

All notable changes to the RemarkableCloud Guacamole PostgreSQL image.

## 1.6.0-r1 - 2026-09-12

- Initial build. Base: `postgres:16` (digest-pinned), preloaded with the Apache Guacamole 1.6.0
  PostgreSQL schema.
- The stock default administrator (`guacadmin`/`guacadmin`) is removed from the schema; an init script
  seeds a generated administrator on first boot from `GUAC_ADMIN_USER` / `GUAC_ADMIN_PASSWORD` (salted
  SHA-256, matching Guacamole's password scheme), so the first visitor can never claim admin.
- Exists because Coolify's docker-compose deploy strips repo-relative bind mounts, so the schema and
  admin seed must be baked into the image rather than mounted into the PostgreSQL init directory.
