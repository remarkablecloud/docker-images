# Code Server

VS Code in the browser (code-server 4.137.0), packaged by RemarkableCloud with a digest-pinned base, a healthcheck, and the login password surfaced to the container log on first run. It runs as a non-root user behind a TLS-terminating reverse proxy, with a persistent /home/coder volume for settings, extensions, and projects.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/code-server:4.137.0-r1
```

## Quick start

A standalone stack is defined in [`docker-compose.yml`](./docker-compose.yml):

```bash
docker compose up -d
# then browse http://localhost:8443 ; read the login password from `docker compose logs`
```

Leave `PASSWORD` unset to auto-generate one (printed once to the log and persisted in the volume), or set it to pin your own.

## More

Full documentation (compose walkthrough, environment reference, hardening, backup, and upgrade guidance) is authored in [`site.md`](./site.md). Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** code-server: MIT
