# Changelog

All notable changes to the RemarkableCloud Nextcloud image are recorded here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
newest first. Each entry is also the source feed for CVE-alert notifications, so
security-relevant changes are called out explicitly. Tags follow the
`<upstream-version>-r<build>` scheme and are immutable, so a redeploy never
silently changes what runs.

## [34.0.3-r1] - 2026-09-10

First changelog entry for the RemarkableCloud Nextcloud image. This build
packages Nextcloud 34.0.3 (Apache and PHP in a single container) for the
RemarkableCloud App Platform. MariaDB and Redis run as separate managed
containers (Redis for the distributed cache and file locking; APCu for the local
cache), and the image is designed to run behind Traefik with TLS terminated at
the proxy.

### Added
- Nextcloud 34.0.3 (`stable-apache`) packaged as a RemarkableCloud image.
- Base image pinned by digest:
  `nextcloud:stable-apache@sha256:b97df9e0e1ee3c8c6cc009cb3f12ddce915d624d543b3bb93882025fe323a407`.
  Pinning by digest means a rebuild picks up base changes only when we bump the
  digest on purpose, and a redeploy cannot drift to a different base.
- Reverse-proxy configuration baked in (`config/zz-rc.config.php`):
  `overwriteprotocol=https`, `trusted_proxies` for the private container
  networks (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`), and
  `overwritehost` plus `overwrite.cli.url` derived from `NC_OVERWRITE_HOST` so
  canonical and CLI URLs follow the customer domain. Copied into the data volume
  on first run.
- `default_phone_region=US` set in the baked config (Nextcloud flags a missing
  phone region as an admin warning).
- Automatic admin password generation on first install (20-character random
  password) when `NEXTCLOUD_ADMIN_PASSWORD` is unset. The value is printed once
  to the container log to be surfaced to the customer.
- PHP tuning (`conf.d/zz-rc.ini`): `expose_php=Off`, OPcache enabled and sized,
  and APCu enabled for the local (per-node) cache.
- `curl` added to the image, and a container `HEALTHCHECK` against `/status.php`
  (interval 30s, timeout 8s, start period 180s, 6 retries) so the platform holds
  traffic until Nextcloud is ready.
- OCI image labels (title, description, vendor, source) for provenance.

### Security
- `expose_php=Off` removes the PHP version banner.
- No admin credential is baked into the image; the first-run password is
  generated at runtime and never stored in the image layers.
- Built on the pinned base above. Future base-OS patches and upstream security
  releases ship as new `-r` builds and appear as new entries here, each with a
  severity marker for the CVE-alert feed.

[34.0.3-r1]: https://github.com/remarkablecloud/apps/tree/main/images/nextcloud
