#!/bin/bash
# RemarkableCloud - seed the Guacamole admin from GUAC_ADMIN_USER / GUAC_ADMIN_PASSWORD with a salted
# SHA-256 hash (Guacamole's scheme: SHA-256(password || UPPERCASE_HEX(salt))), so the default
# guacadmin/guacadmin is never created (the stock 002 seed is omitted from 001-schema.sql). Runs once
# in the postgres initdb phase, right after 001-schema.sql.
set -euo pipefail
: "${GUAC_ADMIN_USER:=admin}"
if [ -z "${GUAC_ADMIN_PASSWORD:-}" ]; then
  echo "[rc] FATAL: GUAC_ADMIN_PASSWORD is empty; refusing to create a passwordless admin" >&2
  exit 1
fi

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
     -v uname="$GUAC_ADMIN_USER" -v pw="$GUAC_ADMIN_PASSWORD" <<'SQL'
CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO guacamole_entity (name, type) VALUES (:'uname', 'USER');

INSERT INTO guacamole_user (entity_id, password_hash, password_salt, password_date)
SELECT e.entity_id,
       digest(:'pw' || upper(encode(s.salt, 'hex')), 'sha256'),
       s.salt,
       CURRENT_TIMESTAMP
FROM guacamole_entity e
CROSS JOIN (SELECT gen_random_bytes(32) AS salt) s
WHERE e.name = :'uname' AND e.type = 'USER';

INSERT INTO guacamole_system_permission (entity_id, permission)
SELECT e.entity_id, v.p::guacamole_system_permission_type
FROM guacamole_entity e,
     (VALUES ('CREATE_CONNECTION'), ('CREATE_CONNECTION_GROUP'), ('CREATE_SHARING_PROFILE'),
             ('CREATE_USER'), ('CREATE_USER_GROUP'), ('ADMINISTER')) v(p)
WHERE e.name = :'uname' AND e.type = 'USER';

INSERT INTO guacamole_user_permission (entity_id, affected_user_id, permission)
SELECT e.entity_id, u.user_id, v.p::guacamole_object_permission_type
FROM guacamole_entity e
JOIN guacamole_user u ON u.entity_id = e.entity_id,
     (VALUES ('READ'), ('UPDATE'), ('ADMINISTER')) v(p)
WHERE e.name = :'uname' AND e.type = 'USER';
SQL

echo "[rc] guacamole admin '$GUAC_ADMIN_USER' seeded (default guacadmin never created)"
