# Use Docker Hub instead of docker.n8n.io to avoid the registry 429 error.
# Pin to the n8n version shown in your logs; update this tag when upgrading n8n.
FROM n8nio/n8n:2.42.7
USER root
RUN apk add --no-cache python3 py3-pip
USER node
