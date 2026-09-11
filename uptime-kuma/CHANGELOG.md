# Changelog

All notable changes to the `ghcr.io/remarkablecloud/uptime-kuma` image are
documented here. The format is based on Keep a Changelog, newest first. Tags
follow the `<upstream version>-rN` scheme, where `rN` is the RemarkableCloud
build revision. This file also feeds the CVE-alert notifications for the image,
so security-relevant changes are called out explicitly.

## [1-r1] - 2026-09-10

Baseline build. Upstream Uptime Kuma 1.x (digest-pinned).

Pinned base image:

```
FROM louislam/uptime-kuma@sha256:3d632903e6af34139a37f18055c4f1bfd9b7205ae1138f1e5e8940ddc1d176f9
```

### Added
- Digest-pinned base so every rebuild of this tag resolves to the exact same
  upstream layer, giving a reproducible starting point for CVE tracking.
- OCI provenance labels (title, description, vendor, source).

### Notes
- This is a straight retag of the upstream `louislam/uptime-kuma` image. It does
  not add a wrapper entrypoint, a new user, or extra services. The upstream
  `HEALTHCHECK` (`extra/healthcheck`) and the upstream `CMD` are kept as-is.
- State lives in the `/app/data` volume with the built-in SQLite database. There
  are no application environment variables to set; the admin account is created
  on the first visit to the web UI.
- No upstream CVE advisories are tracked against this image yet. This entry
  establishes the baseline that later security entries compare against.
