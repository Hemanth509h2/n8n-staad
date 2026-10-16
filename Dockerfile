# Custom n8n image with Python 3 installed.
# Use this to address the "Python 3 is missing" warning when running
# your existing n8n setup in internal/debug task-runner mode.
# For production Python Code nodes, configure n8n's external task runner.

FROM docker.n8n.io/n8nio/n8n:latest

USER root
RUN apk add --no-cache python3 py3-pip

USER node
