# Changelog: Code Server

All notable changes to the RemarkableCloud Code Server image. Newest first.

## [4.137.0-r1] - 2026-09-11

### Added
- Initial RemarkableCloud build of code-server 4.137.0, pinned to `codercom/code-server@sha256:57ac684d44deb6fa94317b3e8f3e128dd7fb897fffd95b4efcd16f56ce607971` (Debian 13, non-root uid 1000).
- HEALTHCHECK on `/healthz`; OCI provenance labels; `image.source` points at this repo.
- Entrypoint wrapper surfaces the auto-generated login password once to the container log (read from `config.yaml`, which persists in the `/home/coder` volume, so the password stays stable across restarts).

### Security
- No credentials baked into the image; the password is generated at first run or supplied via `PASSWORD`.
- Baseline build: no CVE fixes carried yet. Future entries note base-image bumps and any CVEs picked up.
