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

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /root

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
