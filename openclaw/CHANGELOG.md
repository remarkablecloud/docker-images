# Changelog: OpenClaw

All notable changes to the RemarkableCloud OpenClaw image. Newest first.

## [2026.9.4-r1] - 2026-09-11

### Added
- Initial RemarkableCloud build of OpenClaw 2026.9.4 (Node 24, Debian 12), pinned to `ghcr.io/openclaw/openclaw@sha256:cc596b846506a5f4cfcee111394a2725f375f01cca2ebb492a161fd1b747f101`.
- Runs the gateway headlessly behind a reverse proxy: `gateway --allow-unconfigured --auth token --bind lan --port 18789`, so first boot succeeds before the customer configures an LLM key in the Control UI.
- First-run wrapper generates a strong gateway token, persists it in the `/home/node/.openclaw` volume, and prints it once so it can be handed to the customer. A user-supplied `OPENCLAW_GATEWAY_TOKEN` is honoured.
- HEALTHCHECK on `/health`. Local state only (no external database).

### Security
- Token-gated Control UI: the shared gateway token is generated on first boot (never the open/default), so the instance is not left unauthenticated on a public URL.
- No baked credentials; the token lives only in the instance's data volume.
- Note: OpenClaw is an autonomous agent that can execute tasks and browse the web from its container. Treat the gateway token like administrative/shell access and keep it private.
- Baseline build: no CVE fixes carried yet. Future entries note base-image bumps and any CVEs picked up.
