# Changelog

All notable changes to the RemarkableCloud Portainer image.

## 2.45.0-r1 - 2026-09-12

- Initial RemarkableCloud build. Base: `portainer/portainer-ce:2.45.0` (digest-pinned).
- Generated super administrator created on first boot via `--admin-password-file`, fed from the
  `PORTAINER_ADMIN_PASSWORD` environment variable, so the first visitor can never claim the admin
  account (Portainer otherwise waits for a browser-created admin and locks initialization after five
  minutes).
- A static busybox is copied in for the entrypoint, since the official image is distroless.
- Serves plain HTTP on port 9000 for a TLS-terminating reverse proxy (`--http-enabled`), and sets
  `--trusted-origins` so cross-site request checks pass behind the proxy.
