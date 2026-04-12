FROM ubuntu:24.04

RUN apt update && \
    apt install -y git maven gradle python3 openjdk-21-jdk && \
    curl -fsSL https://claude.ai/install.sh | bash && \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc