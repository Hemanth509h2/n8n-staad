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

# Database: the project's Neon Postgres, direct endpoint (never "-pooler"; see
# render-entrypoint.sh). n8n keeps its ~60 tables in their own `n8n` schema,
# which it creates on first start, because the database is shared with the
# backend and feedback-board, whose tables live in `public`.
#
# Only non-secret settings live here: this repo is public. The two secrets,
# DB_POSTGRESDB_PASSWORD and N8N_ENCRYPTION_KEY, come from a .env file loaded
# at startup (Render Secret File /etc/secrets/.env) or from the environment.
ENV DB_TYPE=postgresdb \
    DB_POSTGRESDB_HOST=ep-bold-butterfly-aox1gpwj.c-2.ap-southeast-1.aws.neon.tech \
    DB_POSTGRESDB_PORT=5432 \
    DB_POSTGRESDB_DATABASE=neondb \
    DB_POSTGRESDB_USER=neondb_owner \
    DB_POSTGRESDB_SCHEMA=n8n \
    DB_POSTGRESDB_SSL_ENABLED=true \
    DB_POSTGRESDB_CONNECTION_TIMEOUT=30000

# Keep execution history to 7 days.
ENV EXECUTIONS_DATA_PRUNE=true \
    EXECUTIONS_DATA_MAX_AGE=168

# On Render's free/starter CPU the JS task runner takes 40s+ to boot, which
# outlives the default 30s grant token and fails with "invalid or expired grant
# token ... 403", leaving Code nodes without a runner. Value is in seconds.
ENV N8N_RUNNERS_GRANT_TOKEN_TTL=180

# Pin settings whose defaults n8n is about to change (silences the startup
# deprecation warnings). Task timeout and unverified packages keep today's
# behaviour; the compression limits take the new, smaller defaults since a
# 512 MB instance can't decompress 2 GiB anyway.
ENV N8N_RUNNERS_TASK_TIMEOUT=300 \
    N8N_UNVERIFIED_PACKAGES_ENABLED=true \
    N8N_COMPRESSION_NODE_MAX_DECOMPRESSED_SIZE_BYTES=268435456 \
    N8N_COMPRESSION_NODE_MAX_ZIP_ENTRIES=1000

COPY --chown=root:root --chmod=0755 render-entrypoint.sh /render-entrypoint.sh

USER node

EXPOSE 5678

# For local `docker run`; Render ignores this and uses healthCheckPath instead.
# Uses node because the hardened image doesn't guarantee curl or wget.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD ["node", "-e", "fetch('http://127.0.0.1:'+(process.env.N8N_PORT||process.env.PORT||5678)+'/healthz').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"]

ENTRYPOINT ["tini", "--", "/render-entrypoint.sh"]
