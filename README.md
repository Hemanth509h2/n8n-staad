# n8n on Render

A ready-to-run Docker image for [n8n](https://n8n.io/) (pinned to `n8nio/n8n:2.42.7`), configured for the project's Neon Postgres database.

| File | Purpose |
| --- | --- |
| `Dockerfile` | n8n plus every non-secret setting: Neon host, user, `n8n` schema, SSL, time zone, runner and pruning settings |
| `render-entrypoint.sh` | Loads secrets from a `.env` file, checks the configuration, maps Render's `PORT` and URL onto n8n, then starts n8n |
| `render.yaml` | Render Blueprint: Docker web service in Singapore, next to the Neon database |
| `.env.example` | The two secrets the image needs |

## Secrets

This repo is public, so the image doesn't contain secrets. It needs two, supplied in a `.env` file (see `.env.example`):

| Variable | Value |
| --- | --- |
| `N8N_ENCRYPTION_KEY` | `openssl rand -base64 32`. Keep a copy and never change it, or saved credentials become unreadable. |
| `DB_POSTGRESDB_PASSWORD` | Password of the Neon `neondb_owner` user |

`.env` is git-ignored and excluded from the Docker build, so it never ends up in the repo or the image.

## Run locally

```sh
cp .env.example .env    # then fill in the two secrets
docker build -t n8n-staad .
docker run -it --rm -p 5678:5678 --env-file .env n8n-staad
```

Open http://localhost:5678.

A local run uses the same Neon database and `n8n` schema as Render, so don't run both at the same time, or scheduled workflows will run twice. For a throwaway local instance with its own SQLite database:

```sh
docker run -it --rm -p 5678:5678 -e DB_TYPE=sqlite -v n8n_data:/home/node/.n8n n8n-staad
```

## Deploy on Render

1. Create the service: **New → Blueprint** with this repo, or **New → Web Service** with Runtime **Docker**, region **Singapore** and health check path `/healthz`.
2. Go to **Environment → Secret Files** and add a file named **`.env`** containing your `.env`.
3. Deploy.

On startup `render-entrypoint.sh` loads `/etc/secrets/.env` and:

- refuses to start if `N8N_ENCRYPTION_KEY` is missing (an auto-generated key would be lost on the next deploy);
- refuses to start on a Neon `-pooler` host (see below);
- sets `N8N_PORT`, `N8N_WEBHOOK_URL`, `N8N_EDITOR_BASE_URL` and `N8N_PROXY_HOPS` from Render's `PORT` and `RENDER_EXTERNAL_URL`.

Values in the `.env` file override the Dockerfile defaults, so any n8n setting can be changed there without rebuilding. Plain environment variables work too, if you'd rather not use a Secret File.

**Free plan:** the service sleeps after 15 minutes without traffic, and schedule triggers don't run while it sleeps.

## Database

n8n shares the Neon `neondb` database with the backend and the feedback board, but keeps its tables in its own `n8n` schema, which it creates on first start. The apps' tables in `public` are never touched, and the backend's Prisma only looks at `public`.

It must use Neon's **direct** endpoint. n8n selects its schema with a per-connection `SET search_path`, which Neon's `-pooler` endpoint (PgBouncer in transaction mode) doesn't keep, so n8n's tables could end up in `public`.

## About the Python warning

On startup n8n logs "Failed to start Python task runner in internal mode. because Python 3 is missing from this system." It's harmless: JavaScript Code nodes work normally, and only **Python** Code nodes are unavailable.

Installing Python into this image doesn't fix it. The n8n image is a hardened Alpine image with the package manager removed, and n8n also needs its Python runner and virtualenv, which ship in the separate `n8nio/runners` image. For Python Code nodes, run `n8nio/runners:2.42.7` as a second service in external mode (see the [n8n task runner docs](https://docs.n8n.io/hosting/configuration/task-runners/)).
