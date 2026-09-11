# Changelog: LibreChat

All notable changes to the RemarkableCloud LibreChat image. Newest first.

## [0.8.7-r1] - 2026-09-11

### Added
- Initial RemarkableCloud build of LibreChat 0.8.7 (Node 24, Alpine), pinned to `ghcr.io/danny-avila/librechat@sha256:c5db3331b845e1f289f8d04c0c77936c4bbe372f76730a804abc1c37e44d23a9`. First MongoDB-backed image in the catalog.
- First-run wrapper generates and persists the encryption and auth secrets in the `/app/rc-data` volume: `CREDS_KEY` + `CREDS_IV` (which encrypt the provider API keys users store in the database, so they must stay stable) and `JWT_SECRET` + `JWT_REFRESH_SECRET`.
- Open registration is disabled (`ALLOW_REGISTRATION=false`) and an initial account is created on first run via `create-user` (generated password, printed once). Search (Meilisearch) is off by default for a single-container deployment.
- HEALTHCHECK on `/health` (wget; the upstream image ships no curl).

### Security
- No self-registration: a random visitor cannot create an account and use the owner's LLM credits; the initial account is created by us, and more users are added deliberately.
- Encryption and JWT secrets are generated at runtime and persisted in the data volume, never baked into an image layer; the encryption keys stay stable so stored provider keys remain readable.
- Baseline build: no CVE fixes carried yet. Future entries note base-image bumps and any CVEs picked up.
