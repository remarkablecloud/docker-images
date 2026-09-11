---
title: "Grafana on Docker: the RemarkableCloud image"
slug: grafana
meta_description: "Run Grafana (OSS) in production with Docker Compose using the RemarkableCloud digest-pinned image: non-root, SQLite, healthcheck, admin auto-setup."
keywords:
  - grafana docker
  - grafana docker compose
  - grafana self hosted
  - grafana oss
  - grafana behind traefik
  - grafana sqlite
  - grafana production
  - grafana non root
---

# Grafana on Docker with the RemarkableCloud image

Grafana is an open source analytics and observability platform. It connects to
data sources such as Prometheus, Loki, SQL databases, and many others, then lets
you build dashboards, explore metrics and logs, and set up alerting, all from one
web UI. It is a widely used way to visualize what your systems are doing.

This page documents the RemarkableCloud build of Grafana OSS: what it adds on top
of the upstream image, how to run it with Docker Compose, every environment
variable it reads, and how to keep it backed up and up to date in production.

## What the RemarkableCloud image adds

The RemarkableCloud image is built from the official `grafana/grafana` OSS image
at a pinned digest, with a small wrapper so it comes up ready to use behind a
TLS-terminating proxy such as Traefik. The benefit is a Grafana that starts, has
a known admin login, and stays observable without manual bootstrap.

- **Digest-pinned base.** The build starts from
  `grafana/grafana@sha256:f772d434e8fab0049deb2b1b30abd43342bcfca1537614aa8d36080232cf4283`
  (Grafana 13.2.1 OSS). Pinning by digest means every rebuild of the `13.2.1-r1`
  tag resolves to the exact same upstream layer, which is what makes CVE tracking
  in the [changelog](./CHANGELOG.md) meaningful.
- **First-run admin password generation.** On the very first start, if the
  Grafana database does not yet exist and you have not supplied a password, a
  wrapper entrypoint generates one and prints it once to the container log, then
  hands off to Grafana's own startup.
- **Container healthcheck.** A `HEALTHCHECK` polls `/api/health`, so your
  orchestrator can gate traffic on readiness and restart the container if Grafana
  stops responding.
- **Upstream non-root user preserved.** The image runs as the upstream `grafana`
  user (uid 472). The build switches to root only to install the wrapper, then
  returns to uid 472 for runtime.
- **Provenance labels.** Standard OCI labels record the title, description,
  vendor, and source repository.

Grafana itself (features, plugins model, storage format) is upstream Grafana OSS,
unmodified.

## Run it with Docker Compose

The image ships with a `docker-compose.yml` that is deliberately minimal: one
service, one named volume, SQLite inside the volume, and the admin password
generated on first boot.

```yaml
# RemarkableCloud Grafana - standalone. SQLite; /var/lib/grafana volume; admin pw auto-generated (see logs).
name: grafana
services:
  grafana:
    image: ${GF_IMAGE:-ghcr.io/remarkablecloud/grafana:13.2.1-r1}
    restart: unless-stopped
    ports: ["${HTTP_PORT:-3000}:3000"]
    environment:
      GF_SERVER_ROOT_URL: ${ROOT_URL:-http://localhost:3000}
      GF_SERVER_DOMAIN: ${DOMAIN:-localhost}
      GF_SECURITY_ADMIN_USER: ${GF_ADMIN_USER:-admin}
      GF_SECURITY_ADMIN_PASSWORD: ${GF_ADMIN_PASSWORD:-}
      GF_USERS_ALLOW_SIGN_UP: "false"
    volumes:
      - gf-data:/var/lib/grafana
volumes:
  gf-data:
```

Walking through it:

- **`image`** pins the RemarkableCloud tag by default and lets you override it
  with `GF_IMAGE` for testing a newer build.
- **`restart: unless-stopped`** brings Grafana back after a host reboot or crash.
- **`ports`** publishes the container's port 3000 on the host. In a standalone
  test that is `http://localhost:3000`. In production you leave this on an
  internal network and let the proxy reach 3000 directly.
- **`environment`** sets the public URL, the admin username, and turns off open
  sign-up. `GF_SECURITY_ADMIN_PASSWORD` is intentionally empty so the wrapper
  generates one on first boot.
- **`volumes`** keeps all state (the SQLite database and installed plugins) under
  `/var/lib/grafana` in the named `gf-data` volume.

Start it and read the generated admin password from the log:

```
docker compose up -d
docker compose logs grafana | grep '\[rc\]'
```

You will see a line like `[rc] grafana admin 'admin' password: ...`. The
password is printed once. Store it in your password manager, then sign in.

### Behind Traefik

In production the platform runs Grafana behind Traefik, which terminates TLS. Two
settings matter:

- Set `GF_SERVER_ROOT_URL` (and `GF_SERVER_DOMAIN`) to your real HTTPS hostname.
  Grafana uses the root URL for redirects, links in alert notifications, and
  OAuth callbacks, so it must match what users type in the browser.
- Point the proxy at container port 3000. The healthcheck hits
  `http://127.0.0.1:3000/api/health` inside the container.

## Environment variable reference

`HTTP_PORT` is the host port the compose file publishes; Grafana always listens
on 3000 inside the container.

| Variable | Compose default | Platform value (catalog) | Notes |
|---|---|---|---|
| `GF_IMAGE` | `ghcr.io/remarkablecloud/grafana:13.2.1-r1` | pinned by catalog | Image reference; override only to test a build. |
| `HTTP_PORT` | `3000` | n/a (proxy reaches 3000) | Host port published by compose, mapped to container 3000. |
| `ROOT_URL` -> `GF_SERVER_ROOT_URL` | `http://localhost:3000` | `https://{hostname}` | Public base URL. Drives redirects, alert links, and OAuth callbacks. |
| `DOMAIN` -> `GF_SERVER_DOMAIN` | `localhost` | `{hostname}` | Public hostname. |
| `GF_ADMIN_USER` -> `GF_SECURITY_ADMIN_USER` | `admin` | `admin` | Admin username. |
| `GF_ADMIN_PASSWORD` -> `GF_SECURITY_ADMIN_PASSWORD` | empty | not set (generated) | Only applied on first database init. If empty then, the wrapper generates one and logs it once. |
| `GF_USERS_ALLOW_SIGN_UP` | `false` | `false` | Turns off public self-registration. |

Grafana reads a large number of settings through the `GF_<SECTION>_<KEY>`
environment convention (any value from `grafana.ini`). You can add SMTP,
authentication, or data-source provisioning settings the same way.

## Hardening notes

- **Keep sign-up disabled.** `GF_USERS_ALLOW_SIGN_UP=false` means accounts are
  created by an admin or through configured authentication, not by anonymous
  visitors.
- **Set the root URL over HTTPS.** Terminate TLS at the proxy and serve Grafana
  over HTTPS. A wrong root URL breaks redirects and OAuth logins.
- **This image runs non-root (uid 472).** If you switch from the named volume to
  a bind mount, the host directory must be owned by uid 472
  (`chown -R 472:472 /path/to/grafana-data`), or Grafana cannot write its
  database. Named volumes inherit the correct ownership automatically.
- **Rotate the first-run password.** The generated admin password is written to
  the container log. Sign in, change it, and consider fronting Grafana with your
  own single sign-on for team access.
- **Restrict data-source and plugin access.** Grafana can reach any network your
  container can reach. Place it on a network scoped to the data sources it needs
  rather than a flat network with everything.

## Backups

All runtime state lives in the `/var/lib/grafana` volume: the SQLite database
(dashboards, users, data-source definitions, API keys) and installed plugins.
Backing up that volume backs up the running instance. Note that file-based
provisioning lives outside this volume (upstream default `/etc/grafana/provisioning`),
so if you use it, mount and back up those files separately.

For a consistent file-level backup, stop the container so the SQLite database is
not written mid-copy, archive the volume, then start it again:

```
docker compose stop grafana
docker run --rm -v grafana_gf-data:/data -v "$PWD":/backup alpine \
  tar czf /backup/grafana-data.tgz -C /data .
docker compose start grafana
```

Dashboards can also be version-controlled independently by exporting their JSON
or by using file-based provisioning, which is the more portable option for
disaster recovery. Test a restore into a throwaway stack before you rely on any
backup.

## Upgrades

Grafana applies its own database migrations at startup, so upgrading is usually a
matter of moving to a newer image tag.

1. Read the [changelog](./CHANGELOG.md) and the upstream release notes for the
   target version, watching for breaking changes and deprecations.
2. Back up the `/var/lib/grafana` volume first (see above). Migrations are
   one-way.
3. Pull the new tag, then recreate the container:
   ```
   docker compose pull
   docker compose up -d
   ```
4. Confirm the container reports healthy and check `docker compose logs grafana`
   for migration output. Verify that key plugins are still compatible.

Never downgrade after a migration has run without restoring from a pre-upgrade
backup.

## FAQ

**Where is the admin password?**
It is generated on the first start and printed once to the container log. Run
`docker compose logs grafana | grep '\[rc\]'` right after the first start. To set
it yourself, provide `GF_ADMIN_PASSWORD` before the very first boot.

**I set `GF_ADMIN_PASSWORD` later and nothing changed. Why?**
`GF_SECURITY_ADMIN_PASSWORD` is only applied when Grafana initializes its
database on the first boot. After that, changing it has no effect. Reset the
password from inside the container instead:
```
docker compose exec grafana grafana cli admin reset-admin-password 'NEW_PASSWORD'
```

**Can I use MySQL or PostgreSQL instead of SQLite?**
This image is shipped for the SQLite workflow (`db_mode = none`, no external
database). SQLite is a good fit for a single Grafana instance. An external
database is supported by upstream Grafana but is outside what this image is tuned
for.

**Why does a bind mount fail with permission errors?**
Grafana runs as uid 472. A bind-mounted data directory on the host must be owned
by uid 472. Named volumes do not have this issue.

**Is this the Enterprise edition?**
No. This is Grafana OSS (the open source edition).

**Is this image affiliated with Grafana Labs?**
No. It is an independently built and maintained image that repackages the
official upstream OSS image. It is not endorsed by Grafana Labs.
