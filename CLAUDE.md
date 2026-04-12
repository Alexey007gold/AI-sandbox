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

# Run with a mounted working directory (use start.sh instead)
bash start.sh
```

## Architecture

- **Dockerfile** — single-stage Ubuntu 24.04 image; installs toolchain and Claude Code CLI in one `RUN` layer
- **start.sh** — host-side launcher script; runs the container with volume mounts for the current directory (at the same absolute path), Claude config dirs (`~/.claude`, `~/.claude-mem`, `~/.claude.json`), and `-w $(pwd)` so the shell starts in the host's current directory.