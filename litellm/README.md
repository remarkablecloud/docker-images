# LiteLLM

LiteLLM, an open source LLM gateway that puts 100+ model providers behind one OpenAI-compatible API with an admin UI, packaged by RemarkableCloud with a digest-pinned base, a PostgreSQL backend, and a master key generated on first run so the API and admin UI are gated from the start. You add your own provider API keys and models in the admin UI; it runs behind a TLS-terminating reverse proxy.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/litellm:1.100.1-r1
```

## Quick start

A standalone stack (LiteLLM + PostgreSQL) is defined in [`docker-compose.yml`](./docker-compose.yml):

```bash
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
# then browse http://localhost:4000/ui ; the master key (login + API bearer) is printed in
# `docker compose logs litellm`
```

## More

Full documentation (compose walkthrough, environment reference, hardening, backup, and upgrade guidance) is authored in [`site.md`](./site.md). Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** LiteLLM: MIT
