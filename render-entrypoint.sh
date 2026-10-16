#!/bin/sh
# Fills in the Render-specific settings n8n can't work out by itself, then hands
# off to the stock n8n entrypoint. Anything already set in the environment wins.
set -e

# Render sets RENDER=true. Its filesystem is wiped on every deploy and restart,
# so a key n8n auto-generates into /home/node/.n8n is lost each time, and every
# credential saved in the database with it becomes unreadable. Refuse to start
# rather than lose credentials silently.
if [ -n "$RENDER" ]; then
  if [ -z "$N8N_ENCRYPTION_KEY" ] && [ -z "$N8N_ENCRYPTION_KEY_FILE" ]; then
    echo "ERROR: N8N_ENCRYPTION_KEY is not set." >&2
    echo "Add it under Environment in the Render dashboard (e.g. the output of" >&2
    echo "'openssl rand -base64 32'), keep a copy, and never change it." >&2
    exit 1
  fi
  if [ "$DB_TYPE" != "postgresdb" ]; then
    echo "WARNING: DB_TYPE is not postgresdb, so n8n is using SQLite inside the" >&2
    echo "container. Workflows and credentials will be lost on the next deploy." >&2
  fi
fi

# Render routes traffic to $PORT (10000 unless you set it). Locally PORT is
# unset, so n8n keeps its default 5678.
if [ -z "$N8N_PORT" ] && [ -n "$PORT" ]; then
  export N8N_PORT="$PORT"
fi

# RENDER_EXTERNAL_URL is e.g. https://n8n-service.onrender.com. Without these,
# n8n shows webhook and OAuth callback URLs as http://localhost:5678/...
if [ -n "$RENDER_EXTERNAL_URL" ]; then
  base="${RENDER_EXTERNAL_URL%/}"
  export N8N_WEBHOOK_URL="${N8N_WEBHOOK_URL:-$base/}"
  export N8N_EDITOR_BASE_URL="${N8N_EDITOR_BASE_URL:-$base/}"
  # One reverse proxy (Render's) sits in front of n8n.
  export N8N_PROXY_HOPS="${N8N_PROXY_HOPS:-1}"
fi

exec /docker-entrypoint.sh "$@"
