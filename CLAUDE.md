# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This project defines a Docker container image intended as a sandbox environment for running Claude Code. The container is based on Ubuntu 24.04 and includes:

- Java 21 (OpenJDK)
- Maven and Gradle
- Python 3
- Git
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

- **Dockerfile** — single-stage Ubuntu 24.04 image; installs toolchain and Claude Code CLI in one `RUN` layer
- **start.sh** — host-side launcher; creates the container on first run (detached, `sleep infinity` as PID 1), then `docker exec`es into it on subsequent calls. Mounts `/Users/oleksii/Projects/Auto1` at the same path so it works from any subdirectory. Automatically stops the container when the last session exits.