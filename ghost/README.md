# RemarkableCloud Ghost

Ghost is an open source publishing and newsletter platform for blogs,
publications, and independent creators. This is the RemarkableCloud build of
Ghost 6, with a digest-pinned base image, a reverse-proxy-aware healthcheck, and
fully env-driven configuration for running behind Traefik with an external
MySQL 8 database.

## Pull

```
docker pull ghcr.io/remarkablecloud/ghost:6.63.0-r2
```

## Quick start

Run the standalone stack (Ghost plus MySQL 8 plus a content volume) with
[`docker-compose.yml`](./docker-compose.yml):
`DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d` then open
`http://localhost:8083`.

## Learn more

Full production guide (compose walkthrough, environment reference, hardening,
backups, and upgrades) lives on the RemarkableCloud App Platform page for Ghost:
https://remarkablecloud.com/apps/ghost. Version history and security notes are in
[`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** Ghost: MIT
