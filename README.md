# n8n on Render

A Docker image for [n8n](https://n8n.io/) (pinned to `n8nio/n8n:2.42.7`) plus a Render Blueprint that runs it with a Render Postgres database.

| File | Purpose |
| --- | --- |
| `Dockerfile` | Official n8n image with a time zone, a health check and the Render entrypoint |
| `render-entrypoint.sh` | Maps Render's `PORT` and `RENDER_EXTERNAL_URL` onto n8n's settings, then starts n8n |
| `render.yaml` | Render Blueprint: Docker web service and a Postgres database |

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

**Blueprint (recommended):** push this repo to GitHub, then in Render go to **New → Blueprint** and pick the repo. Render creates `n8n-service` (built from the `Dockerfile`) and the `n8n-db` Postgres database, and wires them together.

**Existing web service:** set **Runtime** to Docker and **Dockerfile path** to `./Dockerfile`, then add these environment variables (values from your Postgres's **Connect → Internal** details):

| Variable | Value |
| --- | --- |
| `N8N_ENCRYPTION_KEY` | A long random string. Never change it afterwards. |
| `DB_TYPE` | `postgresdb` |
| `DB_POSTGRESDB_HOST` | internal host name |
| `DB_POSTGRESDB_PORT` | `5432` |
| `DB_POSTGRESDB_DATABASE` | database name |
| `DB_POSTGRESDB_USER` | user name |
| `DB_POSTGRESDB_PASSWORD` | password |

Set the health check path to `/healthz`.

You don't need to set `PORT`, `N8N_WEBHOOK_URL` or `N8N_EDITOR_BASE_URL`: `render-entrypoint.sh` derives them from Render's `PORT` and `RENDER_EXTERNAL_URL`. If you add a custom domain, set `N8N_WEBHOOK_URL` and `N8N_EDITOR_BASE_URL` to `https://your-domain/`.

**Free plan limits:** the service sleeps after 15 minutes without traffic (schedule triggers don't run while it sleeps), and a free Postgres database expires after 30 days.

## About the Python warning

On startup n8n logs:

> Failed to start Python task runner in internal mode. because Python 3 is missing from this system.

It's harmless: JavaScript Code nodes work normally. Only **Python** Code nodes are unavailable.

Installing Python into this image doesn't fix it:

- The n8n image is a hardened Alpine image with the package manager removed, so neither `apk add` nor `apt-get install` works.
- n8n also needs its Python runner and virtualenv. These ship in the separate `n8nio/runners` image.

For Python Code nodes, run `n8nio/runners:2.42.7` as a second service in external mode (see the [n8n task runner docs](https://docs.n8n.io/hosting/configuration/task-runners/)). On Render that means a paid private service.
