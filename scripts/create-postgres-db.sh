#!/bin/sh
set -eu

# Creates a local PostgreSQL database and app user for this n8n stack.
# Intended for Postgres.app on macOS, but works with any local psql binary.

PSQL_BIN="${PSQL_BIN:-}"
ENV_FILE="${ENV_FILE:-.env}"
ENV_EXAMPLE_FILE="${ENV_EXAMPLE_FILE:-.env.example}"
PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
ADMIN_USER="${ADMIN_USER:-postgres}"
APP_DB="${APP_DB:-n8n}"
APP_USER="${APP_USER:-n8n_app}"
APP_PASSWORD="${APP_PASSWORD:-change_me_to_a_real_password}"
N8N_ENCRYPTION_KEY_VALUE="${N8N_ENCRYPTION_KEY_VALUE:-}"

if [ -z "$PSQL_BIN" ]; then
  if command -v psql >/dev/null 2>&1; then
    PSQL_BIN="$(command -v psql)"
  elif [ -x "/Applications/Postgres.app/Contents/Versions/16/bin/psql" ]; then
    PSQL_BIN="/Applications/Postgres.app/Contents/Versions/16/bin/psql"
  fi
fi

if [ -z "$PSQL_BIN" ] || [ ! -x "$PSQL_BIN" ]; then
  echo "psql not found at: $PSQL_BIN" >&2
  echo "Install PostgreSQL client tools or set PSQL_BIN to your local psql path and retry." >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl not found in PATH." >&2
  exit 1
fi

if [ ! -f "$ENV_FILE" ] && [ -f "$ENV_EXAMPLE_FILE" ]; then
  cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "Env file not found: $ENV_FILE" >&2
  echo "Create it first or provide ENV_FILE=/path/to/.env" >&2
  exit 1
fi

if [ -z "$N8N_ENCRYPTION_KEY_VALUE" ]; then
  N8N_ENCRYPTION_KEY_VALUE="$(openssl rand -hex 32)"
fi

replace_env_value() {
  key="$1"
  value="$2"

  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i '' "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
  else
    printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
  fi
}

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

replace_env_value "POSTGRES_USER" "$APP_USER"
replace_env_value "POSTGRES_PASSWORD" "$APP_PASSWORD"
replace_env_value "POSTGRES_DB" "$APP_DB"
replace_env_value "N8N_ENCRYPTION_KEY" "$N8N_ENCRYPTION_KEY_VALUE"

echo
echo "Database bootstrap completed."
echo "Updated ${ENV_FILE} with:"
echo "  POSTGRES_USER=${APP_USER}"
echo "  POSTGRES_PASSWORD=${APP_PASSWORD}"
echo "  POSTGRES_DB=${APP_DB}"
echo "  N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY_VALUE}"
