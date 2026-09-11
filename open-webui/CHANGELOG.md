# Changelog

All notable changes to the RemarkableCloud Open WebUI image (`ghcr.io/remarkablecloud/open-webui`) are recorded here. The image tracks upstream Open WebUI (the Ollama bundle variant); the `-rN` suffix is the RemarkableCloud build revision of a given upstream version. This file follows Keep a Changelog, newest first, and is the source feed for CVE and security alert notifications.

## [0.11.3-r1] - 2026-09-10

Initial RemarkableCloud build of Open WebUI 0.11.3 with an embedded Ollama runtime. This image ships no language models: pull them from the web UI after first login, or with `docker exec <container> ollama pull <model>`; downloaded models live in the `/root/.ollama` volume. Allow at least 8 GB of RAM once a model is loaded (larger models need more).

- **Upstream:** Open WebUI 0.11.3 (per the RemarkableCloud tag), bundled with an embedded Ollama runtime in a single container (SQLite, no external database).
- **Base image:** `ghcr.io/open-webui/open-webui:ollama@sha256:d4823bc4fad911680a59e8a83a2dd1098969f72d67a9d8f1aabc55db83b8fb24` (the `:ollama` bundle; upstream image label `org.opencontainers.image.version=main-ollama`, commit `0a7c15832fb30b1903753e83f81dc7d27e5b0944`; large, roughly 11 GB; runs as root).

### Added
- Digest-pinned base image for reproducible, auditable builds.
- OCI provenance labels (title, description, vendor, source) for supply-chain traceability.
- Container `HEALTHCHECK` against Open WebUI's `/health` endpoint (uses `curl`), with a long start period so the bundled runtime can initialize before traffic is routed.

### Security
- No CVE fixes in this initial build. This entry establishes the security baseline; future entries will list upstream version bumps and any CVEs picked up from the base image.
