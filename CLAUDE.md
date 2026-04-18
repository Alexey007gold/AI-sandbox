# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This project defines a Docker container image intended as a sandbox environment for running Claude Code. The container is based on Ubuntu 24.04 and includes:

- Node.js 24 (via NVM) + Bun    (used by claude-mem plugin)
- Java 21 and 25 (Oracle, via SDKMAN) + Gradle 9.4.1
- Maven (apt)
- Python 3 + uv
- Git, jq, curl
- socat, iproute2, iptables (for network isolation/forwarding)
- Claude Code CLI (installed via `curl -fsSL https://claude.ai/install.sh | bash`)

## Build & Run

```bash
# Build the image
docker build -t sbx .

# Run interactively
docker run -it sbx bash

# Start/reuse the sandbox container
bash start.sh
```

## Architecture

### Dockerfile

Single-stage Ubuntu 24.04 image. Installs the full toolchain in two `RUN` layers (root for apt/NVM, user for SDKMAN/Claude/Bun/uv).

### start.sh

Host-side launcher with the following responsibilities:

**Container lifecycle:**
- Derives a stable container name from the workspace path (md5 hash) — one container per workspace
- Creates the container on first run, reuses it on subsequent calls (starts if stopped, execs if already running)
- Tracks active sessions via lock files (`/tmp/session.$$`) inside the container; stops the container only when the last session exits (signal trap + cleanup handler)

**Workspace & config mounting:**
- Mounts the Auto1 directory (or current dir) at the same host path inside the container so paths are identical inside and out
- Mounts `~/.claude`, `~/.claude-mem`, and `~/.m2` directly — Claude config, memory, and Maven cache are shared with the host
- Symlinks `/Users/oleksii/.claude → /root/.claude` (and `.claude-mem`) inside the container so plugin `installPaths` referencing the host user path resolve correctly
- Symlinks `claude_.json → .claude.json` (workaround for atomic-rename-safe bind mount)

**Network isolation + selective port forwarding:**
- Applies `iptables` rules to block all outbound traffic to the host gateway except ports **9090, 9091, 37777**
- Uses `socat` to forward those ports from `localhost` inside the container to `host.docker.internal`
- Port **37777** — claude-mem worker (started on the host if not already running before container launch)
- Ports **9090/9091** — local proxy forwarding to anthropic/delorian hosts (configured separately)

**Environment propagation:**
- Passes `TZ`, `KIBANA_QA_API_KEY`, `KIBANA_QA_URL`, and same for prod Kibana into the container

**Session entry:** Drops into `claude --dangerously-skip-permissions` in the correct working directory.