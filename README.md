# n8n Docker image

A ready-to-run Docker image for [n8n](https://n8n.io/) (pinned to `n8nio/n8n:2.42.7`), preconfigured for the project's Neon Postgres database.

| File | Purpose |
| --- | --- |
| `Dockerfile` | n8n plus every non-secret setting: Neon host, user, `n8n` schema, SSL, time zone, runner and pruning settings |
| `.env.example` | The two secrets the image needs |

## Secrets

This repo is public, so the image doesn't contain secrets. It needs two, supplied as environment variables, usually from a `.env` file (see `.env.example`):

| Variable | Value |
| --- | --- |
| `N8N_ENCRYPTION_KEY` | `openssl rand -base64 32`. Keep a copy and never change it, or saved credentials become unreadable. |
| `DB_POSTGRESDB_PASSWORD` | Password of the Neon `neondb_owner` user |

`.env` is git-ignored and excluded from the Docker build, so it never ends up in the repo or the image.

Without `N8N_ENCRYPTION_KEY`, n8n doesn't fail: it generates a key inside the container, which is lost when the container is recreated, and saved credentials become unreadable.

## Run

```sh
cp .env.example .env    # then fill in the two secrets
docker build -t n8n-staad .
docker run -it --rm -p 5678:5678 --env-file .env n8n-staad
```

Open http://localhost:5678. If port 5678 is already in use on your machine, map another host port, e.g. `-p 5680:5678`, and open http://localhost:5680.

When n8n is reachable at a public URL, also set `N8N_WEBHOOK_URL` and `N8N_EDITOR_BASE_URL` to that URL (with a trailing slash), or n8n shows webhook URLs as `http://localhost:5678/...`. Behind a reverse proxy, set `N8N_PROXY_HOPS=1`.

Every instance started with `--env-file .env` uses the same Neon database and `n8n` schema, so run only one at a time, or scheduled workflows will run twice. For a throwaway instance with its own SQLite database:

```sh
docker run -it --rm -p 5678:5678 -e DB_TYPE=sqlite -v n8n_data:/home/node/.n8n n8n-staad
```

## Database

n8n shares the Neon `neondb` database with the backend and the feedback board, but keeps its tables in its own `n8n` schema, which it creates on first start. The apps' tables in `public` are never touched, and the backend's Prisma only looks at `public`.

It must use Neon's **direct** endpoint. n8n selects its schema with a per-connection `SET search_path`, which Neon's `-pooler` endpoint (PgBouncer in transaction mode) doesn't keep, so n8n's tables could end up in `public`.

## About the Python warning

On startup n8n logs "Failed to start Python task runner in internal mode. because Python 3 is missing from this system." It's harmless: JavaScript Code nodes work normally, and only **Python** Code nodes are unavailable.

Installing Python into this image doesn't fix it. The n8n image is a hardened Alpine image with the package manager removed, and n8n also needs its Python runner and virtualenv, which ship in the separate `n8nio/runners` image. For Python Code nodes, run `n8nio/runners:2.42.7` as a second container in external mode (see the [n8n task runner docs](https://docs.n8n.io/hosting/configuration/task-runners/)).
