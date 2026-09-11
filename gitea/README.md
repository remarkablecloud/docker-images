# RemarkableCloud Gitea

Gitea is a lightweight self-hosted Git service with issues, pull requests, and built-in CI. This RemarkableCloud build pins a specific upstream digest, runs headless with the installer locked, and auto-provisions an admin on first start so it comes up ready to use behind Traefik.

## Pull

```
docker pull ghcr.io/remarkablecloud/gitea:1.27.3-r1
```

## Quick start

```
docker compose up -d
```

The bundled `docker-compose.yml` starts Gitea on `http://localhost:3000` with a
persistent `/data` volume. On first run the admin password is generated and
printed to the container log:

```
docker compose logs gitea | grep '\[rc\]'
```

## More

Environment reference, hardening notes, backup and upgrade guidance, and a full
compose walkthrough live in [`site.md`](./site.md), which is published to the
RemarkableCloud docker images documentation section when it goes live.

**Upstream license:** Gitea: MIT
