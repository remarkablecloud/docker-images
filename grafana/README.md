# RemarkableCloud Grafana

Grafana is an open source platform for dashboards and observability across metrics, logs, and traces. This RemarkableCloud build pins a specific upstream digest, keeps the upstream non-root user (uid 472), and auto-generates the admin password on first start so it comes up ready to use behind Traefik.

## Pull

```
docker pull ghcr.io/remarkablecloud/grafana:13.2.1-r1
```

## Quick start

```
docker compose up -d
```

The bundled `docker-compose.yml` starts Grafana on `http://localhost:3000` with
a persistent `/var/lib/grafana` volume. On first run the admin password is
generated and printed to the container log:

```
docker compose logs grafana | grep '\[rc\]'
```

## More

Environment reference, hardening notes, backup and upgrade guidance, and a full
compose walkthrough are published in the RemarkableCloud docker images documentation section on remarkablecloud.com.

**Upstream license:** Grafana OSS: AGPL-3.0-only
