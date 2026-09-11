---
title: "Open WebUI with Ollama on Docker: Production Setup"
slug: "open-webui"
meta_description: "Run Open WebUI with an embedded Ollama in Docker Compose using the RemarkableCloud digest-pinned image for local LLM chat behind Traefik."
keywords:
  - open webui docker
  - open webui ollama
  - open webui docker compose
  - self-hosted llm
  - local llm chat
  - ollama docker
  - open webui traefik
---

# Run Open WebUI with Ollama in Production

Open WebUI is a self-hosted, ChatGPT-style interface for large language models. This build bundles an embedded Ollama runtime in the same container, so one image serves the chat interface and runs the models locally, with all state in SQLite and no external database. You bring your own models by pulling them from the web UI after first login.

This page covers the RemarkableCloud Open WebUI image: what it adds over upstream, a full docker-compose walkthrough, an environment variable reference, and hardening, backup, and upgrade guidance. It also covers the memory sizing this stack needs.

## What the RemarkableCloud image adds

The RemarkableCloud image is a thin build on top of the upstream Open WebUI Ollama bundle (`ghcr.io/open-webui/open-webui:ollama`). That base is large, roughly 11 GB, because it carries both the web application and the Ollama runtime, and it runs as root. On top of it this build adds:

- **Digest-pinned base** for reproducible, auditable builds.
- **OCI provenance labels** (title, description, vendor, source) for supply-chain traceability.
- **Built-in healthcheck** against Open WebUI's `/health` endpoint, with a longer start period so the bundled runtime has time to initialize before traffic is routed.

The application version is pinned to Open WebUI 0.11.3 in the `0.11.3-r1` tag. No models are included; you pull them yourself.

## Memory sizing

The container is light at idle but memory-hungry once a model is loaded, because the model weights are held in RAM by Ollama. Plan for at least 8 GB of RAM as a floor, and more for larger models. The catalog sets an 8 GB minimum for this reason. Choose model sizes that fit the RAM on your plan.

## docker-compose walkthrough

The image ships a standalone `docker-compose.yml`:

```yaml
name: open-webui

services:
  open-webui:
    image: ${OWUI_IMAGE:-ghcr.io/remarkablecloud/open-webui:0.11.3-r1}
    restart: unless-stopped
    ports: ["${HTTP_PORT:-8084}:8080"]
    environment:
      WEBUI_URL: ${WEBUI_URL:-http://localhost:8084}
    volumes:
      - owui-data:/app/backend/data
      - ollama-data:/root/.ollama

volumes:
  owui-data:
  ollama-data:
```

Line by line:

- **image** pins the RemarkableCloud Open WebUI tag, overridable with `OWUI_IMAGE`.
- **restart: unless-stopped** brings the container back after a crash or reboot.
- **ports** maps host port 8084 to container port 8080. This is for standalone runs only. Behind Traefik, no port is published; the proxy routes to port 8080 on the internal network.
- **WEBUI_URL** is the public base URL used for links.
- **volumes** mount two named volumes: `owui-data` at `/app/backend/data` (users, chats, settings in SQLite) and `ollama-data` at `/root/.ollama` (downloaded model weights).

Start it with `docker compose up -d`, open http://localhost:8084, and create the admin account. Then pull a model from Settings > Models, or run `docker exec <container> ollama pull llama3.2`.

## Environment variable reference

| Variable | App Platform value | Standalone default | Notes |
|---|---|---|---|
| `WEBUI_URL` | `https://your-hostname` | `http://localhost:8084` | Public base URL of the interface, no trailing slash. The platform fills the hostname. |
| `HTTP_PORT` | not applicable | `8084` | Host port mapped to container port 8080 in standalone compose only (not published behind Traefik). |
| `OWUI_IMAGE` | not applicable | `ghcr.io/remarkablecloud/open-webui:0.11.3-r1` | Image reference override for standalone compose. |

Models are not configured with environment variables. Pull them from the UI (Settings > Models) after logging in; they are stored in the `ollama-data` volume.

## Hardening notes

- **First account is the admin.** The first account created on a fresh install becomes the administrator. Create it right after deploy, then disable open sign-ups in the admin settings so strangers cannot register.
- **TLS at the proxy.** In production the container serves plain HTTP on 8080 and Traefik terminates TLS. Keep the container off any public port and let the proxy reach it internally.
- **Embedded runtime stays internal.** The bundled Ollama runtime is reachable only inside the container; this compose file does not expose it as a separate service.
- **Runs as root.** The upstream Ollama bundle runs as root. Keep it isolated behind the proxy and do not publish its port.
- **Right-size the model.** Loading a model larger than available RAM will fail or thrash. Match the model to your plan.

## Backup and upgrade

**Backup.** Two volumes hold state. `owui-data` at `/app/backend/data` is the important one: it holds the SQLite database with users, chats, prompts, and settings. Back it up on a schedule. `ollama-data` at `/root/.ollama` holds downloaded model weights, which are large and can be re-pulled at any time, so you can exclude it from backups or place it on a lower tier to save space. For a consistent copy of the app data, snapshot the volume or stop the container briefly.

**Upgrade.** Pull the newer RemarkableCloud tag and recreate the container. Both named volumes persist, so your users, chats, and already-downloaded models carry over. Because state is SQLite, an upgrade is a container swap with no separate database migration step. Read the CHANGELOG for the target tag first, and back up `owui-data` before upgrading.

## FAQ

**Do I need a separate Ollama container?**
No. This image bundles Ollama inside the same container. One service runs both the UI and the models.

**How do I add a model?**
Log in, open Settings > Models, and pull the model you want, or run `docker exec <container> ollama pull <model>`. Models are saved in the `ollama-data` volume.

**Why does it use so much memory?**
Model weights are loaded into RAM when in use. Plan for at least 8 GB, and more for larger models.

**Can I connect an external OpenAI-compatible API instead of local models?**
Yes. Open WebUI supports external OpenAI-compatible endpoints in its settings, in addition to the bundled local runtime.

**Where is my data stored?**
Chats, users, and settings live in the `owui-data` volume (`/app/backend/data`); downloaded models live in the `ollama-data` volume (`/root/.ollama`).
