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

# Run with a mounted working directory
docker run -it -v $(pwd):/$(pwd) sbx bash
```

## Architecture

- **Dockerfile** — single-stage Ubuntu 24.04 image; installs toolchain and Claude Code CLI in one `RUN` layer
- **start.sh** — entrypoint/startup script (currently empty, intended for container initialization logic)

The `PATH` is extended in `~/.bashrc` to include `~/.local/bin` where Claude Code is installed. Note: since `~/.bashrc` is only sourced in interactive shells, running Claude Code in non-interactive Docker `CMD`/`ENTRYPOINT` calls may require sourcing it explicitly or setting `ENV PATH` in the Dockerfile instead.