# OpenClaw

OpenClaw, a self-hosted AI agent gateway, packaged by RemarkableCloud with a digest-pinned base and a token-gated Control UI whose access token is generated on first run so the instance is never left open. It runs behind a TLS-terminating reverse proxy with local state in a single volume and no external database; you add your own LLM API key in the Control UI after connecting with the token.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/openclaw:2026.9.4-r1
```

## Quick start

A standalone stack is defined in [`docker-compose.yml`](./docker-compose.yml):

```bash
docker compose up -d
# the Control UI token is printed in `docker compose logs openclaw`; open http://localhost:18789
# and paste the token into Settings, then add your LLM API key.
```

## More

Full documentation (compose walkthrough, environment reference, hardening, backup, and upgrade guidance) is authored in [`site.md`](./site.md). Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** OpenClaw: MIT
