# n8n local with Docker, Caddy, and host PostgreSQL

This directory runs `n8n` and `caddy` in Docker and connects n8n to a PostgreSQL instance running on the host machine, outside Docker.

Security posture:
- this repository is intended for local development only
- the current PostgreSQL examples are convenience defaults, not production-safe defaults
- do not expose this stack directly to the public internet without revisiting authentication, TLS, and database access controls

Access URLs:
- `https://n8n.local`
- `http://127.0.0.1:5678` for local debug only

## Project structure

- `compose.yaml`: Docker Compose stack for `n8n` and `caddy`
- `.env`: n8n and PostgreSQL connection settings
- `Caddyfile`: local HTTPS reverse proxy for `n8n.local`
- `data/n8n`: persistent n8n application data
- `data/caddy/data`: Caddy certificates and CA state
- `data/caddy/config`: Caddy persistent config state
- `local-files`: local filesystem mount available to workflows

## Prerequisites

- Docker Desktop with Docker Compose
- PostgreSQL running on the host machine
- Database `n8n` already created
- A PostgreSQL user for n8n access
- `host.docker.internal` reachable from Docker containers

## Security warnings

Read this before using the stack as-is:
- using the `postgres` superuser from an application is not a good long-term default
- an empty PostgreSQL password is acceptable only for short-lived local testing
- broad `trust` rules in `pg_hba.conf` reduce friction locally, but they also reduce host-level safety
- trusting a local CA from `mkcert` affects your machine trust store, so keep that CA local to your own workstation
- never commit `.env`, database dumps, `data/`, `certs/`, or private keys

Recommended minimum hardening, even for local development:
- create a dedicated database user such as `n8n_app`
- set a real password in `.env`
- restrict `pg_hba.conf` to the narrowest address range that Docker needs
- keep the repository private if it includes environment-specific operational details

## PostgreSQL requirements

This stack expects PostgreSQL outside Docker with:
- host: `host.docker.internal`
- port: `5432`
- database: `n8n`
- user: ideally a dedicated low-privilege user, not the `postgres` superuser
- password: set a real password unless you are doing short-lived local testing only

Confirm the local PostgreSQL setup before starting:

```bash
psql -h localhost -p 5432 -U postgres -d n8n
```

If the connection fails, check:
- `listen_addresses` includes the interface needed for TCP connections
- `pg_hba.conf` allows the connection method you want to use
- PostgreSQL is actually listening on port `5432`

To verify PostgreSQL is listening:

```bash
lsof -nP -iTCP:5432 -sTCP:LISTEN
```

### Bootstrap the database with Postgres.app

If you use Postgres.app on macOS, this repository includes a helper script to create a dedicated database user and the `n8n` database:

```bash
chmod +x scripts/create-postgres-db.sh
scripts/create-postgres-db.sh
```

Default values used by the script:
- admin user: `postgres`
- app database: `n8n`
- app user: `n8n_app`
- app password: `change_me_to_a_real_password`

You can override them when needed:

```bash
APP_DB=n8n \
APP_USER=n8n_app \
APP_PASSWORD='replace_me' \
scripts/create-postgres-db.sh
```

After running it, update your local `.env` so it matches the created database user and password.

## Local hosts entry

Add this line to `/etc/hosts`:

```text
127.0.0.1 n8n.local
```

On macOS, you can add it with:

```bash
echo '127.0.0.1 n8n.local' | sudo tee -a /etc/hosts
sudo dscacheutil -flushcache
```

Verify local name resolution before opening the browser:

```bash
python3 - <<'PY'
import socket
print(socket.gethostbyname('n8n.local'))
PY
```

Expected result:

```text
127.0.0.1
```

## Configuration

Review `.env` before starting:

```dotenv
POSTGRES_USER=postgres
POSTGRES_PASSWORD=
POSTGRES_DB=n8n
DB_POSTGRESDB_HOST=host.docker.internal
DB_POSTGRESDB_PORT=5432
N8N_ENCRYPTION_KEY=change_me_to_a_long_random_alpha_numeric_string
```

If you clone this repository elsewhere, start from the example file:

```bash
cp .env.example .env
```

Generate a strong encryption key before first real use:

```bash
openssl rand -hex 32
```

Then paste the generated value into:

```dotenv
N8N_ENCRYPTION_KEY=your_generated_value_here
```

Recommended local git safety setup:

```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit
```

Important:
- Replace `N8N_ENCRYPTION_KEY` with a long random value.
- Do not use `postgres` plus an empty password outside temporary local development.
- Prefer a dedicated PostgreSQL user with a real password.
- `localhost` is not correct inside the container for host PostgreSQL. Use `host.docker.internal`.

## Start the stack

```bash
docker compose up -d
```

Inspect the services:

```bash
docker compose ps
docker compose logs -f n8n
docker compose logs -f caddy
```

Validate the compose file before starting if needed:

```bash
docker compose config
```

## Future updates and next steps

This project pins the n8n image version in `compose.yaml`. When you want to update in the future, review the pinned tag first and then refresh the stack in a controlled way.

Recommended update flow for this Docker Compose setup:

```bash
# from this project directory
docker compose pull
docker compose down
docker compose up -d
```

Before updating:
- review the n8n release notes for breaking changes
- check whether `compose.yaml` should move to a newer pinned n8n tag
- keep a backup of your PostgreSQL database and `data/n8n`

After updating:
- run `docker compose ps`
- inspect `docker compose logs -f n8n`
- open `https://n8n.local`
- verify that workflows, credentials, and webhook URLs still behave as expected

Useful official references:
- Docker image README: https://github.com/n8n-io/n8n/tree/master/docker/images/n8n
- Environment variable configuration: https://docs.n8n.io/hosting/configuration/environment-variables/
- Scaling and performance: https://docs.n8n.io/hosting/scaling/overview/
- Quickstarts: https://docs.n8n.io/try-it-out/quickstart/

## Access n8n

Open:

```text
https://n8n.local
```

This setup now uses `mkcert` certificates mounted into Caddy. Your browser will show the normal secure lock once the `mkcert` local CA is trusted by macOS.

The Caddy container still stores runtime state under:
- `data/caddy/data`
- `data/caddy/config`

The project certificate files are stored under:
- `certs/n8n.local.pem`
- `certs/n8n.local-key.pem`

## Caddy, mkcert certificates, and local Certificate Authority

This setup uses Caddy as a local reverse proxy in front of n8n.

In `Caddyfile`, the site is configured with:

```caddy
n8n.local {
	tls /certs/n8n.local.pem /certs/n8n.local-key.pem
	reverse_proxy n8n:5678
}
```

What this means:
- Caddy terminates HTTPS for `n8n.local`
- Caddy serves a certificate generated by `mkcert`
- `mkcert` uses a local development Certificate Authority trusted on the host
- browsers may reject the certificate until that `mkcert` CA is trusted on the host machine

This is useful for web development because:
- you can work locally over `https://`
- webhook URLs and OAuth flows behave more like a real environment
- you get a host-trusted certificate chain suitable for a normal browser lock icon

### Where the mkcert files live

Project-local certificate files:
- `certs/n8n.local.pem`
- `certs/n8n.local-key.pem`

These local certificate files are intentionally not committed to git.

mkcert CA root:
- `/Users/paulo/Library/Application Support/mkcert/rootCA.pem`

### Trusting the mkcert local CA

If the browser shows a certificate warning, the `mkcert` CA is not yet trusted by macOS or by the browser trust store.

Only trust this CA on a machine you control for local development. Do not distribute your local `mkcert` CA or private key.

You can inspect the generated root certificate here:

```text
/Users/paulo/Library/Application Support/mkcert/rootCA.pem
```

If you need to verify that the local cert files exist:

```bash
ls -la certs/
```

Once the CA is trusted by the host, `https://n8n.local` should load with the normal secure lock.

### Green lock on macOS

If you want the browser to show the normal secure lock locally, the `mkcert` CA used to sign `n8n.local` must be trusted by macOS.

The relevant CA file is:

```text
/Users/paulo/Library/Application Support/mkcert/rootCA.pem
```

You can trust it in the login keychain with:

```bash
security add-trusted-cert \
  -d \
  -r trustRoot \
  -k ~/Library/Keychains/login.keychain-db \
  "/Users/paulo/Library/Application Support/mkcert/rootCA.pem"
```

After that:
- fully quit and reopen the browser
- open `https://n8n.local`

If the lock still does not appear:
- confirm `/etc/hosts` contains `127.0.0.1 n8n.local`
- flush the macOS DNS cache with `sudo dscacheutil -flushcache`
- make sure the browser is using the macOS trust store

### Regenerating local certificates

The repository includes a local `mkcert` binary in `bin/mkcert`.

To regenerate the certificate for `n8n.local`:

```bash
./bin/mkcert -cert-file certs/n8n.local.pem -key-file certs/n8n.local-key.pem n8n.local
docker compose restart caddy
```

If the repository is cloned on a different machine, install `mkcert` there first or place a local `mkcert` binary under `bin/`.

## Git and security safeguards

This repository includes a few guardrails for local development:
- `.gitignore` excludes `.env`, `data/`, `certs/`, `local-files/`, and `bin/`
- `.env.example` provides a safe template for configuration
- `.gitattributes` normalizes text files and marks certificate material as binary
- `.githooks/pre-commit` blocks common secret and local-only files from being committed
- `.github/workflows/ci.yml` validates the Compose file and checks for tracked secret-like files

These guardrails reduce common mistakes, but they do not replace manual review before pushing or publishing a fork.

Enable the repository-local git hook after cloning:

```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit
```

### Development note

This certificate model is for local development only. Do not reuse Caddy's internal CA setup as-is for public production traffic.

## Persistence

Persistent local data lives in this directory:
- n8n data: `data/n8n`
- Caddy state: `data/caddy/data`
- Caddy config state: `data/caddy/config`
- workflow local files: `local-files`

You can stop and start the containers without losing n8n state:

```bash
docker compose down
docker compose up -d
```

## Troubleshooting

### n8n cannot connect to PostgreSQL

Symptoms:
- `ECONNREFUSED`
- authentication errors
- migrations failing during startup

Checks:
- confirm PostgreSQL is running on the host
- confirm `psql -h localhost -p 5432 -U postgres -d n8n` works
- confirm `.env` still points to `host.docker.internal`
- confirm PostgreSQL accepts TCP connections without a password for this user

### `host.docker.internal` does not resolve

Test from a disposable container:

```bash
docker run --rm alpine:3.22 getent hosts host.docker.internal
```

If it does not resolve, Docker Desktop may not be running correctly, or your Docker environment may not expose the host gateway alias as expected.

### `n8n.local` does not resolve

Check `/etc/hosts` contains:

```text
127.0.0.1 n8n.local
```

On macOS, if DNS resolution is still stale after editing `/etc/hosts`, run:

```bash
sudo dscacheutil -flushcache
```

Then verify:

```bash
curl -k https://n8n.local
```

If `curl -k --resolve n8n.local:443:127.0.0.1 https://n8n.local` works but `curl -k https://n8n.local` does not, the problem is local hostname resolution, not Docker, Caddy, or n8n.

### Certificate warning in browser

This is expected until you trust the local CA generated by `mkcert`. The relevant CA file is `/Users/paulo/Library/Application Support/mkcert/rootCA.pem`.

### Caddy starts but n8n is unavailable

Check container logs:

```bash
docker compose logs -f n8n
docker compose logs -f caddy
```

If n8n is failing during startup, the most likely cause is PostgreSQL connectivity or authentication.
