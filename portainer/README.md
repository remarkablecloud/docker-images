# Portainer CE

Portainer CE, a web UI for managing Docker (containers, images, volumes, and networks), packaged by RemarkableCloud with a digest-pinned base and a super administrator created with a generated password on first boot, so the first visitor can never claim the admin account. It runs behind a TLS-terminating reverse proxy and manages the host's Docker through the mounted Docker socket.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/portainer:2.45.0-r1
```

## Quick start

A standalone stack is defined in [`docker-compose.yml`](./docker-compose.yml):

```bash
PORTAINER_ADMIN_PASSWORD=$(openssl rand -base64 18) docker compose up -d
# browse http://localhost:9000 and sign in as `admin` with that password
```

## More

Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** Portainer CE: zlib License.
