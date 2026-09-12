# n8n (RemarkableCloud image)

n8n is a workflow automation tool with a visual editor and more than 400 integrations, running on SQLite with no external database. This is the RemarkableCloud build of the upstream n8n image, pinned to a specific digest, run as the non-root node user, with OCI provenance labels and a built-in healthcheck, ready to run behind a Traefik TLS proxy.

## Pull

```
docker pull ghcr.io/remarkablecloud/n8n:2.38.6-r1
```

## Quick start

Run `docker compose up -d` with the bundled `docker-compose.yml`, then open http://localhost:5678 and set up the owner account.

## More

Full guide (compose walkthrough, environment reference, hardening, backup, and upgrade): the n8n page in the RemarkableCloud docker images section on remarkablecloud.com, published alongside this image.

**Upstream license:** n8n: Sustainable Use License (source-available)
