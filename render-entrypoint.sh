#!/bin/sh
# Fills in the Render-specific settings n8n can't work out by itself, then hands
# off to the stock n8n entrypoint. Anything already set in the environment wins.
set -e

# Loads KEY=VALUE lines from a .env file; its values override the image
# defaults and any variable set elsewhere. Read line by line rather than
# sourced, so values are never run as shell code.
load_env_file() {
  [ -r "$1" ] || return 0
  echo "Loading settings from $1"
  cr=$(printf '\r')
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%"$cr"}"
    line="${line#export }"
    case "$line" in ''|'#'*) continue ;; esac
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in ''|[0-9]*|*[!A-Za-z0-9_]*) continue ;; esac
    case "$value" in
      \"*\") value="${value#\"}"; value="${value%\"}" ;;
      \'*\') value="${value#\'}"; value="${value%\'}" ;;
    esac
    export "$key=$value"
  done < "$1"
}

# Render mounts Secret Files at /etc/secrets/<name>. Point ENV_FILE elsewhere
# to use a different file.
load_env_file "${ENV_FILE:-/etc/secrets/.env}"

# Render sets RENDER=true. Its filesystem is wiped on every deploy and restart,
# so a key n8n auto-generates into /home/node/.n8n is lost each time, and every
# credential saved in the database with it becomes unreadable. Refuse to start
# rather than lose credentials silently.
if [ -n "$RENDER" ]; then
  if [ -z "$N8N_ENCRYPTION_KEY" ] && [ -z "$N8N_ENCRYPTION_KEY_FILE" ]; then
    echo "ERROR: N8N_ENCRYPTION_KEY is not set." >&2
    echo "Add your .env as a Secret File named .env (Environment -> Secret Files)," >&2
    echo "or set N8N_ENCRYPTION_KEY as an environment variable. Generate it with" >&2
    echo "'openssl rand -base64 32', keep a copy, and never change it." >&2
    exit 1
  fi
  if [ "$DB_TYPE" != "postgresdb" ]; then
    echo "WARNING: DB_TYPE is not postgresdb, so n8n is using SQLite inside the" >&2
    echo "container. Workflows and credentials will be lost on the next deploy." >&2
  fi
fi

# n8n points each connection at its schema with a session-level
# `SET search_path` (and sets statement_timeout the same way). A transaction
# pooler like Neon's "-pooler" endpoint drops session settings between
# transactions, so n8n's tables could be created in, and read from, `public`.
case "$DB_POSTGRESDB_HOST" in
  *-pooler.*)
    echo "ERROR: DB_POSTGRESDB_HOST is a connection-pooler endpoint ($DB_POSTGRESDB_HOST)." >&2
    echo "Use the direct endpoint instead: the same host without '-pooler'." >&2
    exit 1
    ;;
esac

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
