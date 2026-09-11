# Changelog

All notable changes to the `ghcr.io/remarkablecloud/gitea` image are documented
here. The format is based on Keep a Changelog, newest first. Tags follow the
`<upstream version>-rN` scheme, where `rN` is the RemarkableCloud build revision
of that upstream version. This file also feeds the CVE-alert notifications for
the image, so security-relevant changes are called out explicitly.

## [1.27.3-r1] - 2026-09-10

Baseline build. Upstream Gitea 1.27.3.

Pinned base image:

```
FROM gitea/gitea@sha256:87a67ee09d3ae0d1df5fda5dcda3e2a1f9236a45b0a59025d6e00e46adc43bef
```

### Added
- Digest-pinned base so every rebuild of this tag resolves to the exact same
  upstream layer, giving a reproducible starting point for CVE tracking.
- First-run admin provisioning wrapper (`rc-entrypoint.sh`). On first start it
  waits for `/api/healthz`, creates an admin account with
  `gitea admin user create --admin`, and prints the generated password once to
  the container log. A generated password is used when `GITEA_ADMIN_PASSWORD` is
  empty. The step is idempotent through a marker at
  `/data/gitea/conf/.rc-admin-done` and runs in the background so it never blocks
  startup.
- Container `HEALTHCHECK` against `/api/healthz`
  (interval 30s, timeout 5s, start period 45s, 5 retries) so the orchestrator can
  see readiness and restart on failure.
- OCI provenance labels (title, description, vendor, source).

### Notes
- Ships headless: the install wizard is locked and configuration is supplied
  through environment variables. The catalog and the bundled `docker-compose.yml`
  set `INSTALL_LOCK=true`, `DISABLE_REGISTRATION=true`, the SQLite backend, and
  `ROOT_URL` / `DOMAIN` from the deployment hostname. These are deployment
  defaults, not baked into the image.
- Runs the upstream s6 process layout as root, the same as `gitea/gitea`; this
  build does not change the upstream user model.
- No upstream CVE advisories are tracked against this image yet. This entry
  establishes the baseline that later security entries compare against.
