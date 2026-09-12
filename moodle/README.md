# Moodle

Moodle, the open source learning management system (LMS) for courses, quizzes, grades, and activities, packaged by RemarkableCloud as a from-source build on a digest-pinned `php:8.4-apache` base (PHP 8.4, Apache mod_php, Debian 13), backed by PostgreSQL 17. A headless CLI install creates the administrator with a generated password before Apache serves its first request, so the operator is never made admin through the browser wizard, and the Moodle code lives on a volume so UI-installed plugins and themes persist across upgrades.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/moodle:5.2.2-r1
```

## Quick start

A standalone stack (Moodle + PostgreSQL 17) is defined in [`docker-compose.yml`](./docker-compose.yml):

```bash
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
# first boot seeds the code and installs the database (about 3 to 5 minutes); the
# admin login is printed in `docker compose logs moodle`, then browse http://localhost:8094
```

## More

Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

Moodle is a registered trademark. RemarkableCloud packages the open source project independently and is not affiliated with or endorsed by Moodle.

**Upstream license:** Moodle: GPL-3.0-or-later.
