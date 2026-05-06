FROM node:22-bookworm-slim

ARG SUPERCRONIC_VERSION=v0.2.33

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gettext-base \
        git \
        jq \
        tini \
    && rm -rf /var/lib/apt/lists/*

RUN ARCH=$(dpkg --print-architecture) \
    && case "$ARCH" in \
        amd64) BIN=supercronic-linux-amd64 ;; \
        arm64) BIN=supercronic-linux-arm64 ;; \
        *) echo "Unsupported arch: $ARCH" >&2 && exit 1 ;; \
    esac \
    && curl -fsSLo /usr/local/bin/supercronic \
        "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/${BIN}" \
    && chmod +x /usr/local/bin/supercronic

RUN npm install -g \
        @anthropic-ai/claude-code \
        @softeria/ms-365-mcp-server \
    && npm cache clean --force

# Run as non-root. claude CLI refuses --dangerously-skip-permissions as root,
# which is required for unattended cron invocations. The node base image
# already provides a 'node' user at UID 1000, which matches the typical
# first-user UID on Debian — bind-mounted host paths created by the SSH
# deploy user are writable without chowning.
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER node
WORKDIR /home/node

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
