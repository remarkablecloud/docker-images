# Changelog: Mattermost

All notable changes to the RemarkableCloud Mattermost image. Newest first.

## [11.10.1-r1] - 2026-09-11

### Added
- Initial RemarkableCloud build of Mattermost Team Edition 11.10.1, pinned to `mattermost/mattermost-team-edition@sha256:8285b96eb412d89dd308e4c1ad9cc7f1a9dc9edcd798167b55bc35f1c7ee69d1`. First PostgreSQL-backed image in the catalog.
- The upstream image is distroless (no shell); we add a static busybox for a first-boot wrapper and the healthcheck (wget).
- First-boot wrapper creates a generated system administrator via `mmctl --local` (unix socket, no exposed credentials) once the server is up, persists the password in the data volume, and prints it once.
- PostgreSQL via `MM_SQLSETTINGS_*` (auto-migrates on start). HEALTHCHECK on `/api/v4/system/ping`.

### Security
- No public-first-admin: the system admin is created by us on first boot, and open sign-up plus email sign-up are disabled by default (`ENABLEOPENSERVER=false`, `ENABLESIGNUPWITHEMAIL=false`), so a random visitor cannot claim the admin role or self-register.
- No baked credentials; the admin password lives only in the instance's data volume.
- Baseline build: no CVE fixes carried yet. Future entries note base-image bumps and any CVEs picked up.
