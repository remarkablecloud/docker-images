# Changelog

All notable changes to the `ghcr.io/remarkablecloud/grafana` image are
documented here. The format is based on Keep a Changelog, newest first. Tags
follow the `<upstream version>-rN` scheme, where `rN` is the RemarkableCloud
build revision of that upstream version. This file also feeds the CVE-alert
notifications for the image, so security-relevant changes are called out
explicitly.

## [13.2.1-r1] - 2026-09-11

Baseline build. Upstream Grafana 13.2.1 (OSS).

Pinned base image:

```
FROM grafana/grafana@sha256:f772d434e8fab0049deb2b1b30abd43342bcfca1537614aa8d36080232cf4283
```

### Added
- Digest-pinned base so every rebuild of this tag resolves to the exact same
  upstream layer, giving a reproducible starting point for CVE tracking.
- First-run admin password generation wrapper (`rc-entrypoint.sh`). When the
  Grafana database does not yet exist and no `GF_SECURITY_ADMIN_PASSWORD` is
  provided, the wrapper generates a 20-character password, exports it for
  Grafana's first-boot bootstrap, and prints it once to the container log. It
  then hands off to the upstream `/run.sh`.
- Container `HEALTHCHECK` against `/api/health`
  (interval 30s, timeout 5s, start period 45s, 5 retries) so the orchestrator
  can see readiness and restart on failure.
- OCI provenance labels (title, description, vendor, source).

### Notes
- The image keeps the upstream non-root `grafana` user (uid 472). The Dockerfile
  briefly switches to root only to make the wrapper executable, then returns to
  uid 472 for runtime. Bind-mounted data directories must be owned by uid 472;
  named volumes inherit the correct ownership automatically.
- Ships behind a proxy: the catalog and the bundled `docker-compose.yml` set
  `GF_SERVER_ROOT_URL` / `GF_SERVER_DOMAIN` from the deployment hostname and set
  `GF_USERS_ALLOW_SIGN_UP=false`. These are deployment defaults, not baked into
  the image.
- SQLite is the shipped database backend (`db_mode = none`); state lives in the
  `/var/lib/grafana` volume.
- No upstream CVE advisories are tracked against this image yet. This entry
  establishes the baseline that later security entries compare against.
