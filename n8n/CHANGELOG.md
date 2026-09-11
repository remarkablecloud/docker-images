# Changelog

All notable changes to the RemarkableCloud n8n image (`ghcr.io/remarkablecloud/n8n`) are recorded here. The image tracks upstream n8n; the `-rN` suffix is the RemarkableCloud build revision of a given upstream version. This file follows Keep a Changelog, newest first, and is the source feed for CVE and security alert notifications.

## [2.38.6-r1] - 2026-09-10

Initial RemarkableCloud build of n8n 2.38.6.

- **Upstream:** n8n 2.38.6 (workflow automation, SQLite, no external database).
- **Base image:** `n8nio/n8n@sha256:7406a977895d0158ab0f5b2a3dc66de636711f36c06f0e2e2b1c391fc91f8ec3` (Alpine, runs as the non-root `node` user).

### Added
- Digest-pinned base image for reproducible, auditable builds.
- OCI provenance labels (title, description, vendor, source) for supply-chain traceability.
- Container `HEALTHCHECK` against n8n's `/healthz` readiness endpoint (uses `wget`, which ships in the base; `curl` does not), so the orchestrator only routes traffic to a ready instance.
- Ownership fix that creates `/home/node/.n8n` and assigns it to `node`, so a mounted persistent volume stays writable.

### Security
- No CVE fixes in this initial build. This entry establishes the security baseline; future entries will list upstream version bumps and any CVEs picked up from the base image.
