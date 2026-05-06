# claude-agent

Container image for running scheduled Claude Code jobs against a Claude Max subscription. Runtime only — no skills, prompts, or crontab live in this repo. Those are mounted in by the deployer.

Image: `ghcr.io/camsoper/claude-agent:latest` (also tagged `sha-<short>` per build).

## What's in the image

- `node:22-bookworm-slim` base
- [`@anthropic-ai/claude-code`](https://www.npmjs.com/package/@anthropic-ai/claude-code) CLI
- [`@softeria/ms-365-mcp-server`](https://www.npmjs.com/package/@softeria/ms-365-mcp-server)
- [`supercronic`](https://github.com/aptible/supercronic) as PID 1, run with `-inotify` so crontab edits hot-reload
- `tini` for signal handling, `envsubst` for templating, `jq`, `git`, `curl`

## Expected mount points

The image is inert without the deployer providing these:

| Path inside container | Purpose | Typical mode |
| --- | --- | --- |
| `/home/claude/.claude/` | Claude credentials, MCP token caches, projects state | rw, persistent |
| `/home/claude/.claude/skills/` | Skills directory (overlay on the auth volume) | ro |
| `/etc/claude-agent/mcp.json.tmpl` | MCP server declarations with `${VAR}` placeholders | ro |
| `/etc/supercronic/crontab` | Job schedule | ro |

The entrypoint renders `mcp.json.tmpl` to `/home/claude/.mcp.json` (project-scope, picked up because `WORKDIR` is `/root`) using `envsubst`, then execs supercronic.

## Bootstrap (one-time, post-deploy)

Both steps require an interactive TTY. Run them after the container is up:

### 1. Claude Max login

```bash
docker exec -it claude-agent claude setup-token
```

Follow the OAuth prompt from any browser. The credential persists at `/home/claude/.claude/.credentials.json` on the auth volume and survives image rebuilds.

### 2. Microsoft 365 device flow

The first time an `ms-365-mcp-server` tool is invoked, it prints a device code. Trigger it manually so you can complete the flow:

```bash
docker exec -it claude-agent claude -p "list my upcoming calendar events" --dangerously-skip-permissions
```

Visit `https://microsoft.com/devicelogin`, enter the code, approve. Tokens cache to disk in the auth volume.

## Crontab format

Standard cron, plus `claude` invocations. Always include `--dangerously-skip-permissions` — there's no human to approve tool use during scheduled runs.

```cron
# m  h  dom mon dow  command
  0  9  *   *   *    claude -p "summarize today's calendar" --dangerously-skip-permissions
```

## MCP template format

Same shape as a project-scope `.mcp.json`. `envsubst` substitutes `${VAR}` from the container's environment at startup, so secrets stay out of git.

```json
{
  "mcpServers": {
    "ms-365": {
      "command": "ms-365-mcp-server",
      "args": []
    }
  }
}
```

## Deploy

This image is consumed by [`home-lab-iac`](https://github.com/CamSoper/home-lab-iac) (private). The Pulumi project pins a specific SHA tag and bind-mounts content from a sibling `claude-agent-content/` directory.

## Local smoke test

```bash
docker build -t claude-agent:dev .
docker run --rm -it \
    -v "$PWD/test/auth:/root/.claude" \
    -v "$PWD/test/skills:/home/claude/.claude/skills:ro" \
    -v "$PWD/test/mcp.json:/etc/claude-agent/mcp.json.tmpl:ro" \
    -v "$PWD/test/crontab:/etc/supercronic/crontab:ro" \
    claude-agent:dev
```
