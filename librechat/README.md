# LibreChat

LibreChat, a self-hosted multi-provider AI chat interface (a ChatGPT-style UI for OpenAI, Anthropic, and many other models), packaged by RemarkableCloud with a digest-pinned base, a MongoDB backend, and open registration disabled with an initial account created on first run so a random visitor cannot self-register and spend your LLM credits. Its encryption and auth secrets are generated and persisted, and it runs behind a TLS-terminating reverse proxy.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/librechat:0.8.7-r1
```

## Quick start

A standalone stack (LibreChat + MongoDB) is defined in [`docker-compose.yml`](./docker-compose.yml):

```bash
docker compose up -d
# then browse http://localhost:3080 ; the login is printed in `docker compose logs librechat`
```

## More

Full documentation (compose walkthrough, environment reference, hardening, backup, and upgrade guidance) is authored in [`site.md`](./site.md). Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** LibreChat: MIT
