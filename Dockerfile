FROM ubuntu:24.04

ENV NVM_DIR=/root/.nvm
ENV SDKMAN_DIR=/root/.sdkman
ENV NODE_VERSION=24
ENV PATH="/root/.local/bin:$SDKMAN_DIR/candidates/java/current/bin:$PATH"
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update \
    && apt install -y --no-install-recommends git maven gradle python3 python-is-python3 zip unzip curl socat jq \
    && rm -rf /var/lib/apt/lists/* \
    && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default \
    && ln -sf "$NVM_DIR/versions/node/$(nvm current)/bin/"* /usr/local/bin/ \
    && useradd -m -d /root -s /bin/bash user \
    && echo 'user ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && chown -R user:user /root

USER user

RUN curl -s "https://get.sdkman.io" | bash \
    && bash -c "source $SDKMAN_DIR/bin/sdkman-init.sh \
        && sdk install java 21.0.10-oracle \
        && sdk install java 21 $SDKMAN_DIR/candidates/java/21.0.10-oracle \
        && sdk install java 25.0.2-oracle \
        && sdk install java 25 $SDKMAN_DIR/candidates/java/25.0.2-oracle" \
    && rm -rf $SDKMAN_DIR/archives/* \
    && curl -fsSL https://claude.ai/install.sh | bash \
    && echo 'source "$HOME/.sdkman/bin/sdkman-init.sh"' >> /root/.bashrc
