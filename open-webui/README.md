# Open WebUI + Ollama (RemarkableCloud image)

Open WebUI is a ChatGPT-style interface for local large language models, and this build bundles an embedded Ollama runtime so one container serves the chat UI and runs models on SQLite with no external database. This is the RemarkableCloud build of the upstream Open WebUI Ollama bundle, pinned to a specific digest, with OCI provenance labels and a built-in healthcheck, ready to run behind a Traefik TLS proxy.

## Pull

```
docker pull ghcr.io/remarkablecloud/open-webui:0.11.3-r1
```

## Quick start

Run `docker compose up -d` with the bundled `docker-compose.yml`, open http://localhost:8084, create the admin account, then pull a model from Settings > Models (allow at least 8 GB of RAM once a model is loaded).

## More

Full guide (compose walkthrough, environment reference, hardening, backup, and upgrade): the Open WebUI page in the RemarkableCloud docker images section on remarkablecloud.com, published alongside this image. Maintainers: that page is generated from `site.md` in this directory.

**Upstream license:** Open WebUI: BSD-3-Clause with branding clause; Ollama: MIT
