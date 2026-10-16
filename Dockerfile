
FROM n8nio/n8n:2.42.7

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

USER node
