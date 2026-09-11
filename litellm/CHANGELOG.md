# Changelog: LiteLLM

All notable changes to the RemarkableCloud LiteLLM image. Newest first.

## [1.100.1-r1] - 2026-09-11

### Added
- Initial RemarkableCloud build of LiteLLM 1.100.1 (Python 3.13, Wolfi), pinned to `ghcr.io/berriai/litellm@sha256:a3715fa7ad8387941ab697259bd2881d68931657247a41984f90fae6d11c62bf`.
- PostgreSQL backend (Prisma, auto-migrated on start) for the admin UI, virtual keys, and spend tracking; models are managed in the database (`STORE_MODEL_IN_DB`), so no config file is needed.
- First-run wrapper generates a master key and a salt key, persists both in the `/app/rc-data` volume, and prints the master key once. A user-supplied `LITELLM_MASTER_KEY` / `LITELLM_SALT_KEY` is honoured.
- HEALTHCHECK on `/health/liveliness` (python-based; the upstream image ships no curl).

### Security
- API and admin UI are gated by the generated master key from first boot (no open access); `/v1/*` returns 401 without a valid key.
- The salt key (which encrypts provider API keys stored in the database) and the master key are persisted in the data volume and are never baked into an image layer; the salt stays stable so stored keys remain readable.
- Baseline build: no CVE fixes carried yet. Future entries note base-image bumps and any CVEs picked up.
