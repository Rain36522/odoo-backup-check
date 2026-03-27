#!/usr/bin/env bash

# This scrypte take the last db dump. He generate a new db, try to read some data and delete it.

set -euo pipefail

# charge .env (même dossier que le script)
set -a
source ".env"
set +a

# dernier dump (d'abord .dump, sinon .sql)
DUMP_FILE="$(ls -1t "odoo-backup"/*.dump 2>/dev/null | head -1 || true)"
[ -z "${DUMP_FILE:-}" ] && DUMP_FILE="$(ls -1t "odoo-backup"/*.sql 2>/dev/null | head -1 || true)"
if [ -z "${DUMP_FILE:-}" ]; then
  echo "[!] aucun backup trouvé dans odoo-backup"
  exit 1
fi

TESTDB="odoo_test_$(date +%F_%H%M)"
echo "[i] test restore depuis $DUMP_FILE -> $TESTDB"

dex() { docker exec -i postgresql bash -lc "$*"; }

# 1) create DB
dex "PGPASSWORD='$DB_PWD' createdb -U '$DB_USER' \"$TESTDB\""

# 2) restore
if [[ "$DUMP_FILE" == *.dump ]]; then
  # format custom (-Fc)
  dex "PGPASSWORD='$DB_PWD' pg_restore -U '$DB_USER' -d \"$TESTDB\"" < "$DUMP_FILE"
else
  # .sql plain
  dex "PGPASSWORD='$DB_PWD' psql -U '$DB_USER' -d \"$TESTDB\"" < "$DUMP_FILE"
fi

# 3) checks
USERS=$(dex "PGPASSWORD='$DB_PWD' psql -U '$DB_USER' -d \"$TESTDB\" -Atc \"select count(*) from res_users;\"")
PARTNERS=$(dex "PGPASSWORD='$DB_PWD' psql -U '$DB_USER' -d \"$TESTDB\" -Atc \"select count(*) from res_partner;\"")

if [ "${USERS:-0}" -lt 1 ] || [ "${PARTNERS:-0}" -lt 1 ]; then
  echo "[!] KO: users=$USERS partners=$PARTNERS (dump: $(basename "$DUMP_FILE"))"
  # ne pas drop: on garde pour debug
  exit 1
fi

# 4) cleanup
dex "PGPASSWORD='$DB_PWD' dropdb -U '$DB_USER' \"$TESTDB\""
echo "[✓] OK: users=$USERS partners=$PARTNERS (dump: $(basename "$DUMP_FILE"))"
