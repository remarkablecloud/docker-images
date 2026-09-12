# Guacamole PostgreSQL

PostgreSQL 16 preloaded with the Apache Guacamole 1.6.0 database schema and a **generated administrator** created on first boot, packaged by RemarkableCloud for the App Platform. The stock `guacadmin`/`guacadmin` account is never created: the admin username and password come from `GUAC_ADMIN_USER` / `GUAC_ADMIN_PASSWORD` and are applied (salted SHA-256, per Guacamole's scheme) during PostgreSQL initialization.

This is a building block for the Guacamole deploy (paired with `guacamole/guacd` and `guacamole/guacamole`), not a standalone product.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/guacamole-db:1.6.0-r1
```

## More

Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream licenses:** PostgreSQL License (PostgreSQL); Apache-2.0 (the Guacamole database schema).
