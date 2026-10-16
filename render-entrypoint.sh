#!/bin/sh
# Fills in the Render-specific settings n8n can't work out by itself, then hands
# off to the stock n8n entrypoint. Anything already set in the environment wins.
set -e

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
