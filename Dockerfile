FROM ubuntu:22.04

ARG NONROOT_USER=scaladev
ENV NONROOT_USER=${NONROOT_USER}
ENV HOME=/home/${NONROOT_USER}

###############################################################################
# (1) Base image: locale, dev tools, user, aliases, etc.
###############################################################################
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
SHELL ["/bin/bash", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget gnupg software-properties-common dirmngr ca-certificates \
    unzip build-essential gcc g++ make git git-lfs nano xz-utils \
    sudo python3 python3-pip python3-distutils bash-completion locales \
    lsb-release postgresql-client libpq-dev \
  && rm -rf /var/lib/apt/lists/* \
  && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen \
  && mkdir -p /usr/share/nano-syntax \
  && curl -fsSL https://raw.githubusercontent.com/scopatz/nanorc/master/install.sh | bash \
  && useradd -m -s /bin/bash ${NONROOT_USER} \
  && printf "%s ALL=(ALL) NOPASSWD:ALL\n" "${NONROOT_USER}" > /etc/sudoers.d/${NONROOT_USER} \
  && chmod 0440 /etc/sudoers.d/${NONROOT_USER} \
  && cp /etc/skel/.bash* ${HOME}/ \
  && printf "include /usr/share/nano-syntax/*.nanorc\nexport EDITOR=nano\n" >> ${HOME}/.nanorc \
  && printf "alias ll='ls -la'\nalias la='ls -A'\n..." >> ${HOME}/.bash_aliases \
  && chown -R ${NONROOT_USER}:${NONROOT_USER} ${HOME}

###############################################################################
# (2) Docker CLI + Compose
###############################################################################
RUN install -m0755 -d /etc/apt/keyrings \
  && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
     | gpg --dearmor -o /usr/share/keyrings/docker.gpg \
  && printf "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] \
     https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\n" \
     > /etc/apt/sources.list.d/docker.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
       docker-ce docker-ce-cli containerd.io \
       docker-compose-plugin docker-buildx-plugin \
  && apt-get clean && rm -rf /var/lib/apt/lists/* \
  && groupadd -f docker && usermod -aG docker ${NONROOT_USER} \
  && mkdir -p ${HOME}/.docker && chown -R ${NONROOT_USER}:docker ${HOME}/.docker

###############################################################################
# (3) kubectl
###############################################################################
RUN cd /tmp \
  && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
  && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256" \
  && echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check \
  && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
  && rm kubectl kubectl.sha256 \
  && kubectl completion bash > /etc/bash_completion.d/kubectl \
  && printf "alias k='kubectl'\ncomplete -o default -F __start_kubectl k\n" \
     >> ${HOME}/.bash_aliases \
  && kubectl version --client

###############################################################################
# (4) Java + Scala 3 + sbt
###############################################################################
ENV SCALA_VERSION=3.7.0
# JDK
RUN apt-get update && apt-get install -y openjdk-21-jdk wget \
  && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV PATH="$JAVA_HOME/bin:$PATH"

# Scala 3 binary
RUN wget https://github.com/scala/scala3/releases/download/${SCALA_VERSION}/scala3-${SCALA_VERSION}-x86_64-pc-linux.tar.gz \
  -O /tmp/scala.tar.gz \
  && tar -xzf /tmp/scala.tar.gz -C /opt \
  && ln -s /opt/scala3-${SCALA_VERSION} /opt/scala \
  && rm /tmp/scala.tar.gz

ENV PATH="/opt/scala/bin:$PATH"

# sbt binary
ENV SBT_VERSION=1.10.11
RUN wget https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz \
     -O /tmp/sbt.tgz \
 && tar -xzf /tmp/sbt.tgz -C /opt \
 && ln -s /opt/sbt/bin/sbt /usr/local/bin/sbt \
 && rm /tmp/sbt.tgz
 
 ###############################################################################
 # (5) Install Node.js via NVM for JavaScript scripting support
 ###############################################################################
 ENV NVM_DIR=/usr/local/nvm
 ENV NVM_VERSION=0.40.3
 ENV NODE_VERSION=22.2.0

 # Create NVM dir first, then install Node via NVM
 RUN mkdir -p $NVM_DIR && \
     curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash && \
     . "$NVM_DIR/nvm.sh" && \
     export NVM_DIR=$NVM_DIR && \
     [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && \
     nvm install $NODE_VERSION && \
     nvm use $NODE_VERSION && \
     nvm alias default $NODE_VERSION && \
     npm install -g tsx typescript

 # Persist NVM in shell for all future sessions
 RUN printf "export NVM_DIR=%s\n" "$NVM_DIR" >> /etc/profile.d/nvm.sh && \
     printf '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"\n' >> /etc/profile.d/nvm.sh && \
     printf "export PATH=\$NVM_DIR/versions/node/v%s/bin:\$PATH\n" "$NODE_VERSION" >> /etc/profile.d/nvm.sh && \
     chmod +x /etc/profile.d/nvm.sh

 ENV PATH=$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH


###############################################################################
# (6) Final
###############################################################################
USER ${NONROOT_USER}
WORKDIR /workspace
CMD ["bash", "-i"]
