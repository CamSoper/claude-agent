#!/usr/bin/env bash
set -euo pipefail

MCP_TEMPLATE="/etc/claude-agent/mcp.json.tmpl"
MCP_RENDERED="/root/.mcp.json"
CRONTAB="/etc/supercronic/crontab"

if [ -f "$MCP_TEMPLATE" ]; then
    envsubst < "$MCP_TEMPLATE" > "$MCP_RENDERED"
    echo "[claude-agent] rendered $MCP_RENDERED"
else
    echo "[claude-agent] no MCP template at $MCP_TEMPLATE; skipping"
fi

if [ ! -f "$CRONTAB" ]; then
    echo "[claude-agent] ERROR: no crontab at $CRONTAB" >&2
    exit 1
fi

exec supercronic -passthrough-logs -inotify "$CRONTAB"
