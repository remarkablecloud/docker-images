# Vaultwarden (RemarkableCloud image)

Vaultwarden is a lightweight, Bitwarden-compatible password manager server written in Rust, storing your vault on SQLite in a single persistent volume with no external database. This is the RemarkableCloud build of the upstream Vaultwarden server, pinned to a specific digest, with OCI provenance labels and a built-in healthcheck, ready to run behind a Traefik TLS proxy.

## Pull

```
docker pull ghcr.io/remarkablecloud/vaultwarden:1-r1
```

## Quick start

Set your public URL and run `DOMAIN=https://vault.example.com docker compose up -d` with the bundled `docker-compose.yml`, then open http://localhost:8086, create your account, and set `SIGNUPS_ALLOWED=false` to close registration.

## More

Full guide (compose walkthrough, environment reference, hardening, backup, and upgrade): the Vaultwarden page in the RemarkableCloud docker images section on remarkablecloud.com, published alongside this image. Maintainers: that page is generated from `site.md` in this directory.

**Upstream license:** Vaultwarden: AGPL-3.0-only
