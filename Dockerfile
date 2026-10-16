# syntax=docker/dockerfile:1

# n8n for Render (also runs locally with plain `docker run`).
#
# Pulled from Docker Hub rather than docker.n8n.io to avoid that registry's
# 429 rate limits. Keep the tag pinned: n8n migrates the database on start,
# so bump it deliberately and never move back to an older version.
#
# Don't add `apk add` / `apt-get install` steps here. The official image is a
# hardened Alpine image with apk-tools removed (and it was never Debian), so
# neither package manager exists inside it.
#
# The "Failed to start Python task runner in internal mode" log line is only a
# warning: JavaScript Code nodes still work. Installing python3 here would not
# fix it, because n8n also needs its Python runner virtualenv, which ships in
# the separate n8nio/runners image (see README).
FROM n8nio/n8n:2.42.7

ENV NODE_ENV=production \
    GENERIC_TIMEZONE=Asia/Kolkata \
    TZ=Asia/Kolkata \
    N8N_DIAGNOSTICS_ENABLED=false \
    N8N_PERSONALIZATION_ENABLED=false

COPY --chown=root:root --chmod=0755 render-entrypoint.sh /render-entrypoint.sh

USER node

EXPOSE 5678

# For local `docker run`; Render ignores this and uses healthCheckPath instead.
# Uses node because the hardened image doesn't guarantee curl or wget.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD ["node", "-e", "fetch('http://127.0.0.1:'+(process.env.N8N_PORT||process.env.PORT||5678)+'/healthz').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"]

ENTRYPOINT ["tini", "--", "/render-entrypoint.sh"]
