#!/bin/sh
set -eu

# Creates a local PostgreSQL database and app user for this n8n stack.
# Intended for Postgres.app on macOS, but works with any local psql binary.

PSQL_BIN="${PSQL_BIN:-/Applications/Postgres.app/Contents/Versions/16/bin/psql}"
PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
ADMIN_USER="${ADMIN_USER:-postgres}"
APP_DB="${APP_DB:-n8n}"
APP_USER="${APP_USER:-n8n_app}"
APP_PASSWORD="${APP_PASSWORD:-change_me_to_a_real_password}"

if [ ! -x "$PSQL_BIN" ]; then
  echo "psql not found at: $PSQL_BIN" >&2
  echo "Set PSQL_BIN to your local psql path and retry." >&2
  exit 1
fi

echo "Using psql: $PSQL_BIN"
echo "Host: $PGHOST"
echo "Port: $PGPORT"
echo "Admin user: $ADMIN_USER"
echo "App database: $APP_DB"
echo "App user: $APP_USER"

"$PSQL_BIN" \
  -v ON_ERROR_STOP=1 \
  -h "$PGHOST" \
  -p "$PGPORT" \
  -U "$ADMIN_USER" \
  -d postgres <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${APP_USER}') THEN
    EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', '${APP_USER}', '${APP_PASSWORD}');
  ELSE
    EXECUTE format('ALTER ROLE %I WITH LOGIN PASSWORD %L', '${APP_USER}', '${APP_PASSWORD}');
  END IF;
END
\$\$;

SELECT format('CREATE DATABASE %I OWNER %I', '${APP_DB}', '${APP_USER}')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = '${APP_DB}')
\gexec

GRANT ALL PRIVILEGES ON DATABASE "${APP_DB}" TO "${APP_USER}";
SQL

echo
echo "Database bootstrap completed."
echo "Update .env to match these values:"
echo "  POSTGRES_USER=${APP_USER}"
echo "  POSTGRES_PASSWORD=${APP_PASSWORD}"
echo "  POSTGRES_DB=${APP_DB}"
