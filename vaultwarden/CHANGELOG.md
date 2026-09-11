# Changelog

All notable changes to the RemarkableCloud Vaultwarden image (`ghcr.io/remarkablecloud/vaultwarden`) are recorded here. The image tracks the upstream Vaultwarden 1.x line; the `-rN` suffix is the RemarkableCloud build revision. This file follows Keep a Changelog, newest first, and is the source feed for CVE and security alert notifications.

## [1-r1] - 2026-09-10

Initial RemarkableCloud build of Vaultwarden.

- **Upstream:** Vaultwarden 1.37.2 (Bitwarden-compatible server written in Rust; SQLite, no external database). The image tag `1-r1` tracks the upstream 1.x major and is pinned by digest to this exact release.
- **Base image:** `vaultwarden/server@sha256:094b5689ed81549bd293418395c7cf495ae9d960fc2d4928cef2083ef913d912` (Vaultwarden 1.37.2; runs as root).

### Added
- Digest-pinned base image for reproducible, auditable builds.
- OCI provenance labels (title, description, vendor, source) for supply-chain traceability.
- Container `HEALTHCHECK` against Vaultwarden's `/alive` endpoint (uses `curl`), so the orchestrator only routes traffic to a ready instance.

### Security
- No CVE fixes in this initial build. This entry establishes the security baseline; future entries will list upstream version bumps and any CVEs picked up from the base image.
- Registration is open by default (`SIGNUPS_ALLOWED=true`) so the first account can be created. Set it to `false` immediately afterward to close public registration.
