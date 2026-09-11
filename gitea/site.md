---
title: "Gitea on Docker: the RemarkableCloud hardened image"
slug: gitea
meta_description: "Run Gitea in production with Docker Compose using the RemarkableCloud digest-pinned image: headless setup, SQLite, healthcheck, admin auto-provisioning."
keywords:
  - gitea docker
  - gitea docker compose
  - gitea self hosted
  - gitea sqlite
  - gitea behind traefik
  - gitea production
  - self hosted git server
  - gitea hardened image
---

# Gitea on Docker with the RemarkableCloud image

Gitea is a self-hosted Git service. It gives a team its own place to host
repositories, review pull requests, track issues, run built-in Actions CI, and
publish releases and packages, all from a single lightweight binary that runs
comfortably on a small server. If you want the workflow of a hosted Git platform
without sending your source code to a third party, Gitea is a direct answer.

This page documents the RemarkableCloud build of Gitea: what it adds on top of
the upstream image, how to run it with Docker Compose, every environment
variable it reads, and how to keep it backed up and up to date in production.

## What the RemarkableCloud image adds

The RemarkableCloud image is built from the official `gitea/gitea` image at a
pinned digest, with a small amount of glue so it comes up ready to use behind a
TLS-terminating proxy such as Traefik. The benefit is a Gitea that starts, logs
in, and stays observable without a manual setup wizard.

- **Digest-pinned base.** The build starts from
  `gitea/gitea@sha256:87a67ee09d3ae0d1df5fda5dcda3e2a1f9236a45b0a59025d6e00e46adc43bef`
  (Gitea 1.27.3). Pinning by digest means every rebuild of the `1.27.3-r1` tag
  resolves to the exact same upstream layer, which is what makes CVE tracking in
  the [changelog](./CHANGELOG.md) meaningful.
- **First-run admin provisioning.** A wrapper entrypoint waits for the app to
  report healthy, then creates an admin account and prints the generated
  password once to the container log. You never touch a browser-based installer.
- **Container healthcheck.** A `HEALTHCHECK` polls `/api/healthz`, so your
  orchestrator can gate traffic on readiness and restart the container if Gitea
  stops responding.
- **Headless by configuration.** The catalog ships the install lock on, public
  registration off, SQLite as the database, and the public URL derived from the
  deployment hostname, so the instance is private and correctly linked from the
  first request.
- **Provenance labels.** Standard OCI labels record the title, description,
  vendor, and source repository.

Everything in Gitea itself (features, storage format, Git internals) is upstream
Gitea, unmodified.

## Run it with Docker Compose

The image ships with a `docker-compose.yml` that is deliberately minimal: one
service, one named volume, SQLite inside the volume, and the admin password
generated on first boot.

```yaml
# RemarkableCloud Gitea - standalone (SQLite; /data volume; auto-provisioned admin).
#   docker compose up -d   -> http://localhost:3000  (admin password printed in the logs)
# Production runs behind a TLS-terminating proxy; the catalog sets ROOT_URL/DOMAIN from the hostname.
name: gitea

services:
  gitea:
    image: ${GITEA_IMAGE:-ghcr.io/remarkablecloud/gitea:1.27.3-r1}
    restart: unless-stopped
    ports: ["${HTTP_PORT:-3000}:3000"]
    environment:
      GITEA__server__ROOT_URL: ${ROOT_URL:-http://localhost:3000/}
      GITEA__server__DOMAIN: ${DOMAIN:-localhost}
      GITEA__server__HTTP_PORT: "3000"
      GITEA__database__DB_TYPE: sqlite3
      GITEA__security__INSTALL_LOCK: "true"
      GITEA__service__DISABLE_REGISTRATION: "true"
      GITEA_ADMIN_USER: ${GITEA_ADMIN_USER:-admin}
      GITEA_ADMIN_PASSWORD: ${GITEA_ADMIN_PASSWORD:-}
      GITEA_ADMIN_EMAIL: ${GITEA_ADMIN_EMAIL:-admin@example.com}
    volumes:
      - gitea-data:/data

volumes:
  gitea-data:
```

Walking through it:

- **`image`** pins the RemarkableCloud tag by default and lets you override it
  with `GITEA_IMAGE` for testing a newer build.
- **`restart: unless-stopped`** brings Gitea back after a host reboot or crash.
- **`ports`** publishes the container's port 3000 on the host. In a standalone
  test that is `http://localhost:3000`. In production you leave this on an
  internal network and let the proxy reach 3000 directly.
- **`environment`** locks the installer, turns off open registration, selects
  SQLite, and sets the public URL. `GITEA_ADMIN_PASSWORD` is intentionally
  empty so the first-run wrapper generates one.
- **`volumes`** keeps all state (repositories, the SQLite database, config,
  avatars, LFS) under `/data` in the named `gitea-data` volume.

Start it and read the generated admin password from the log:

```
docker compose up -d
docker compose logs gitea | grep '\[rc\]'
```

You will see a line like `[rc] gitea admin 'admin' created; password: ...`. The
password is printed once. Store it in your password manager, then sign in and
change it or add SSH keys as needed.

### Behind Traefik

In production the platform runs Gitea behind Traefik, which terminates TLS. Two
settings matter:

- Set `ROOT_URL` (and `DOMAIN`) to your real HTTPS hostname. Gitea uses
  `ROOT_URL` to build every link and clone URL, so this must match what users
  type in the browser.
- Point the proxy at container port 3000. The healthcheck hits
  `http://127.0.0.1:3000/api/healthz` inside the container, which returns 200
  regardless of the request host, so it is never redirected by `ROOT_URL`.

## Environment variable reference

`HTTP_PORT` and `GITEA__server__HTTP_PORT` are different settings that happen to
share a word: the first is the host port the compose file publishes, the second
is the port Gitea listens on inside the container. Leave the container port at
3000.

| Variable | Compose default | Platform value (catalog) | Notes |
|---|---|---|---|
| `GITEA_IMAGE` | `ghcr.io/remarkablecloud/gitea:1.27.3-r1` | pinned by catalog | Image reference; override only to test a build. |
| `HTTP_PORT` | `3000` | n/a (proxy reaches 3000) | Host port published by compose, mapped to container 3000. |
| `ROOT_URL` -> `GITEA__server__ROOT_URL` | `http://localhost:3000/` | `https://{hostname}/` | Public base URL. Drives all generated links and clone URLs. |
| `DOMAIN` -> `GITEA__server__DOMAIN` | `localhost` | `{hostname}` | Public hostname. |
| `GITEA__server__HTTP_PORT` | `3000` | `3000` | Port Gitea listens on inside the container. Keep at 3000. |
| `GITEA__database__DB_TYPE` | `sqlite3` | `sqlite3` | Database backend. This image is shipped SQLite-only. |
| `GITEA__security__INSTALL_LOCK` | `true` | `true` | Locks the web installer so Gitea starts headless. |
| `GITEA__service__DISABLE_REGISTRATION` | `true` | `true` | Turns off public self-registration. |
| `GITEA_ADMIN_USER` | `admin` | `admin` | Username created on first run. |
| `GITEA_ADMIN_EMAIL` | `admin@example.com` | `admin@example.com` | Email for the first-run admin. |
| `GITEA_ADMIN_PASSWORD` | empty | not set (generated) | If empty, the wrapper generates a 20-character password and logs it once. |

Gitea reads many more settings through the `GITEA__section__KEY` convention. Any
value from `app.ini` can be supplied as an environment variable, so you can add,
for example, SMTP or storage settings the same way.

## Hardening notes

- **Keep registration closed.** `DISABLE_REGISTRATION=true` means new users are
  created by an admin. If you deliberately open signups, pair it with an
  allowlist or email-domain restriction.
- **Set a strong `ROOT_URL` over HTTPS.** Terminate TLS at the proxy and never
  serve Gitea over plain HTTP in production. The image expects a proxy in front.
- **Publish only the HTTP port.** The compose file maps port 3000 only. Gitea
  will still display SSH-style clone URLs (`git@host:owner/repo.git`), but SSH
  is not published by this setup, so use the HTTPS clone URLs the web UI shows,
  or publish and configure SSH deliberately if your team needs it.
- **This image runs as root internally.** It keeps the upstream `gitea/gitea`
  process model (an s6 supervisor that drops to the `git` user for Gitea
  itself). That is the supported upstream layout; do not assume a rootless
  container.
- **Rotate the first-run password.** The generated admin password is written to
  the container log. Sign in, change it, and consider enabling two-factor
  authentication on the admin account.

## Backups

All state lives in the `/data` volume: the SQLite database, repositories,
config, LFS objects, and avatars. Backing up that volume backs up the whole
instance.

For a consistent snapshot, use Gitea's own dump, which packages the database and
repositories together:

```
docker compose exec -u git -w /tmp gitea gitea dump -c /data/gitea/conf/app.ini -f /tmp/gitea-dump.zip
docker compose cp gitea:/tmp/gitea-dump.zip ./gitea-dump.zip
```

Writing the dump to `/tmp` keeps it out of `/data`, which avoids write-permission
issues and stops the dump from bloating later volume backups.

For a simple file-level backup, stop the container and archive the volume so the
SQLite database is not written mid-copy:

```
docker compose stop gitea
docker run --rm -v gitea_gitea-data:/data -v "$PWD":/backup alpine \
  tar czf /backup/gitea-data.tgz -C /data .
docker compose start gitea
```

Test a restore into a throwaway stack before you rely on any backup.

## Upgrades

Gitea applies its own database migrations automatically at startup, so upgrading
is usually a matter of moving to a newer image tag.

1. Read the [changelog](./CHANGELOG.md) and the upstream release notes for the
   target version, watching for breaking changes.
2. Back up the `/data` volume first (see above). SQLite migrations are one-way.
3. Pull the new tag, then recreate the container:
   ```
   docker compose pull
   docker compose up -d
   ```
4. Confirm the container reports healthy and check `docker compose logs gitea`
   for migration output.

Move one minor version at a time for large jumps, and never downgrade after a
migration has run without restoring from a pre-upgrade backup.

## FAQ

**Where is the admin password?**
It is generated on first run and printed once to the container log. Run
`docker compose logs gitea | grep '\[rc\]'` right after the first start. To set
it yourself, provide `GITEA_ADMIN_PASSWORD` before the very first boot.

**How do I reset a lost admin password?**
Use Gitea's own CLI inside the container:
```
docker compose exec -u git gitea gitea admin user change-password --username admin --password 'NEW_PASSWORD'
```

**Can I use MySQL or PostgreSQL instead of SQLite?**
This image is shipped for the SQLite workflow (`db_mode = none`, no external
database). SQLite is a good fit for small to medium teams. Moving to an external
database is possible with upstream Gitea but is outside what this image is
tuned for.

**Why can't I clone over SSH?**
The compose file publishes only the HTTP port (3000). Gitea still renders
`git@host` clone URLs, but the SSH port is not published by the compose file or
the platform. Use the HTTPS clone URL shown in the repository page, or publish
and configure SSH yourself.

**Does the install wizard ever appear?**
No. `INSTALL_LOCK=true` disables it. All configuration is supplied through
environment variables and the `/data` volume.

**Is this image affiliated with the Gitea project?**
No. It is an independently built and maintained image that repackages the
official upstream image. It is not endorsed by the Gitea project.
