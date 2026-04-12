FROM ubuntu:24.04

RUN apt update
RUN apt install -y git maven gradle python3 openjdk-21-jdk
RUN apt install -y npm

RUN apt install -y python-is-python3
RUN apt install -y curl

ENV NVM_DIR=/root/.nvm
ENV NODE_VERSION=24
ENV DEBIAN_FRONTEND=noninteractive
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default \
    && ln -sf "$NVM_DIR/versions/node/$(nvm current)/bin/"* /usr/local/bin/

RUN useradd -m -d /root -s /bin/bash user \
    && echo 'user ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && chown user:user /root

USER user

RUN curl -fsSL https://claude.ai/install.sh | bash

ENV PATH="/root/.local/bin:$PATH"
