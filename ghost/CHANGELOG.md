# Changelog

All notable changes to the RemarkableCloud Ghost image are recorded here. The
format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), newest
first. Each entry is also the source feed for CVE-alert notifications, so
security-relevant changes are called out explicitly. Tags follow the
`<upstream-version>-r<build>` scheme and are immutable, so a redeploy never
silently changes what runs.

## [6.63.0-r2] - 2026-09-10

First changelog entry. Covers the currently promoted build, `6.63.0-r2`; an
earlier `6.63.0-r1` tag of the same upstream version exists and is superseded by
this one. This build packages Ghost 6.63.0 for the RemarkableCloud App Platform;
Ghost 6 requires MySQL 8 (provisioned as a separate managed container), and the
image is designed to run behind Traefik with TLS terminated at the proxy
(`url=https://<hostname>`).

### Added
- Ghost 6.63.0 (Node 22, Alpine) packaged as a RemarkableCloud image.
- Base image pinned by digest:
  `ghost:alpine@sha256:04a47602872ead868582b04129e035673ea68324bc97c2ed4a181b7c142152b8`.
  Pinning by digest means a rebuild picks up base changes only when we bump the
  digest on purpose, and a redeploy cannot drift to a different base.
- Container `HEALTHCHECK` against the Ghost admin-site API
  (`/ghost/api/admin/site/`). The probe sends `X-Forwarded-Proto: https` so it
  receives a 200 instead of following Ghost's HTTP to HTTPS redirect, which lets
  the platform hold traffic until the app is genuinely ready
  (interval 30s, timeout 8s, start period 120s, 6 retries).
- Fully env-driven configuration (`url`, `NODE_ENV`, `database__*`); nothing
  environment-specific is baked into the image, so the same artifact runs in dev
  and in production.
- OCI image labels (title, description, vendor, source) for provenance.

### Security
- Built on the pinned base above. Future base-OS patches and upstream security
  releases ship as new `-r` builds and appear as new entries here, each with a
  severity marker for the CVE-alert feed.

[6.63.0-r2]: https://github.com/remarkablecloud/apps/tree/main/images/ghost
