# RemarkableCloud Uptime Kuma

Uptime Kuma is a self-hosted uptime monitor with status pages and alerting. This RemarkableCloud build is a digest-pinned rebuild of the upstream image with provenance labels added, keeping the upstream healthcheck and data layout so it runs predictably behind Traefik.

## Pull

```
docker pull ghcr.io/remarkablecloud/uptime-kuma:1-r1
```

## Quick start

```
docker compose up -d
```

The bundled `docker-compose.yml` starts Uptime Kuma on `http://localhost:3001`
with a persistent `/app/data` volume. Open the page and create the admin account
on your first visit.

## More

Setup walkthrough, hardening notes, backup and upgrade guidance, and a full
compose reference are published in the RemarkableCloud docker images documentation section on remarkablecloud.com.

**Upstream license:** Uptime Kuma: MIT
