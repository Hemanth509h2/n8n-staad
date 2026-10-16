# n8n on Render

A Docker image for [n8n](https://n8n.io/) (pinned to `n8nio/n8n:2.42.7`) plus a Render Blueprint that runs it against the project's Neon Postgres database.

| File | Purpose |
| --- | --- |
| `Dockerfile` | Official n8n image with a time zone, a health check and the Render entrypoint |
| `render-entrypoint.sh` | Checks the encryption key and database host, maps Render's `PORT` and `RENDER_EXTERNAL_URL` onto n8n's settings, then starts n8n |
| `render.yaml` | Render Blueprint: Docker web service in Singapore, next to the Neon database |

## Run locally

```sh
docker build -t n8n-staad .
docker run -it --rm --name n8n \
  -p 5678:5678 \
  -v n8n_data:/home/node/.n8n \
  n8n-staad
```

Open http://localhost:5678. Locally n8n uses SQLite inside the `n8n_data` volume, so your data survives restarts.

## Deploy on Render

**Blueprint (recommended):** push this repo to GitHub, then in Render go to **New → Blueprint** and pick the repo. Render creates `n8n-service` in Singapore and asks for the database host, user and password.

**Existing web service:** set **Runtime** to Docker and **Dockerfile path** to `./Dockerfile`, then add these environment variables:

| Variable | Value |
| --- | --- |
| `PORT` | `5678` |
| `N8N_ENCRYPTION_KEY` | A long random string (`openssl rand -base64 32`). Never change it afterwards. |
| `DB_TYPE` | `postgresdb` |
| `DB_POSTGRESDB_HOST` | Neon's **direct** host: the one from your connection string, without `-pooler` |
| `DB_POSTGRESDB_PORT` | `5432` |
| `DB_POSTGRESDB_DATABASE` | `neondb` |
| `DB_POSTGRESDB_USER` | `neondb_owner` |
| `DB_POSTGRESDB_PASSWORD` | the password from the connection string |
| `DB_POSTGRESDB_SSL_ENABLED` | `true` |
| `DB_POSTGRESDB_CONNECTION_TIMEOUT` | `30000` |

Set the health check path to `/healthz`.

You don't need to set `N8N_WEBHOOK_URL` or `N8N_EDITOR_BASE_URL`: `render-entrypoint.sh` derives them from Render's `RENDER_EXTERNAL_URL`. If you add a custom domain, set `N8N_WEBHOOK_URL` and `N8N_EDITOR_BASE_URL` to `https://your-domain/`. Don't use the old `WEBHOOK_URL` name, which n8n 2.x has deprecated.

Without `PORT`, Render has to detect the port itself, logs "New primary port detected: 5678" and restarts the deploy once.

Create the service in the **Singapore** region to sit next to the Neon database (aws ap-southeast-1). Render can't move an existing service to another region, so a service in another region has to be recreated.

**Free plan limits:** the service sleeps after 15 minutes without traffic (schedule triggers don't run while it sleeps).

## Database

n8n shares the Neon `neondb` database with the backend and the feedback board, but keeps its tables in its own `n8n` schema (`DB_POSTGRESDB_SCHEMA=n8n` in the `Dockerfile`). n8n creates the schema on first start. The apps' tables in `public` are never touched, and the backend's Prisma only looks at `public`, so it won't try to drop n8n's tables.

It must use Neon's **direct** endpoint. n8n selects its schema with a per-connection `SET search_path`, which Neon's `-pooler` endpoint (PgBouncer in transaction mode) doesn't keep, so n8n's tables could end up in `public`. `render-entrypoint.sh` refuses to start on a `-pooler` host.

## About the Python warning

On startup n8n logs:

> Failed to start Python task runner in internal mode. because Python 3 is missing from this system.

It's harmless: JavaScript Code nodes work normally. Only **Python** Code nodes are unavailable.

Installing Python into this image doesn't fix it:

- The n8n image is a hardened Alpine image with the package manager removed, so neither `apk add` nor `apt-get install` works.
- n8n also needs its Python runner and virtualenv. These ship in the separate `n8nio/runners` image.

For Python Code nodes, run `n8nio/runners:2.42.7` as a second service in external mode (see the [n8n task runner docs](https://docs.n8n.io/hosting/configuration/task-runners/)). On Render that means a paid private service.
