# Install GH
FROM quay.io/app-sre/ocm-container:latest as builder
ARG GITHUB_TOKEN

RUN dnf install --assumeyes jq tar gzip

# GH CLI
RUN mkdir /gh
WORKDIR /gh
ARG BIN_URL="https://api.github.com/repos/cli/cli/releases/latest"
ARG BIN_SELECTOR='linux_amd64.tar.gz$'
ARG BIN_ASSET="gh.tar.gz"
RUN curl -o ${BIN_ASSET} -sSLf -O $(curl -sSLf ${BIN_URL} -o - | jq -r --arg SELECTOR "$BIN_SELECTOR" '.assets[] | select(.name|test($SELECTOR)) | .browser_download_url')
RUN tar --extract --gunzip --no-same-owner --strip-components=2 --file ${BIN_ASSET}

FROM quay.io/app-sre/ocm-container:latest
MAINTAINER "Chris Collins <chris.collins@redhat.com>"

ARG BIN_DIR="/usr/local/bin"
ARG PKGS="openldap-clients jq tar gzip krb5-devel python3-devel clang nodejs-npm"
ARG NPM_PKGS="@anthropic-ai/claude-code@latest"

ARG GIT_HASH="xxxxxxxx"

RUN dnf install --assumeyes 'dnf-command(config-manager)' \
    && dnf install --assumeyes openldap-clients jq tar gzip krb5-devel python3-devel clang nodejs-npm \
    && dnf clean all \
    && rm --recursive --force /var/cache/yum/

RUN python3 -m pip install rh-aws-saml-login

# Claude Code
RUN npm install -g $NPM_PKGS

# Install Google Coud CLI
ARG GCLOUD_CLI="https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64"
ARG GCLOUD_CLI_REPO_NAME="google-cloud-cli"
ARG GCLOUD_KEYS="https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg"

ADD repofiles/google-cloud-cli.repo /etc/yum.repos.d/google-cloud-cli.repo

# Policy rejects F09C394C3E1BA8D5: No binding signature at time 2025-11-03T17:58:56Z 
# RHEL 10 has a stricter set of policies by default 
RUN update-crypto-policies --set LEGACY
RUN rpm --import $GCLOUD_KEYS \
    && dnf install --assumeyes libxcrypt-compat \
    && dnf install --assumeyes --enablerepo=${GCLOUD_CLI_REPO_NAME} google-cloud-cli \
    && dnf clean all \
    && rm --recursive --force /var/cache/yum/

# Install TMUX
COPY --from=quay.io/chcollin/tmux:latest /tmux ${BIN_DIR}
RUN tmux -V

# Install GH
COPY --from=builder /gh/gh ${BIN_DIR}
RUN gh --version

# Add Glow
ARG CHARM_REPO_NAME="charm"
ARG CHARM_KEYS="https://repo.charm.sh/yum/gpg.key"

ADD repofiles/charm.repo /etc/yum.repos.d/charm.repo

RUN rpm --import $GCLOUD_KEYS \
    && dnf install --assumeyes --enablerepo=${CHARM_REPO_NAME} glow \
    && dnf clean all \
    && rm --recursive --force /var/cache/yum/

# Relative to TMPDIR
RUN mkdir -p /root/.bashrc.d
COPY bashrc.d/* /root/.bashrc.d/

RUN mkdir -p /root/.local/bin
COPY utils/* /root/.local/bin

# Tmux configuration
COPY .tmux.conf /root/.tmux.conf

# NO RHEL10 REPO YET
## Install Vault CLI
#RUN dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
#RUN dnf install --assumeyes vault terraform

LABEL ocm_container_custom_version=${GIT_HASH}
ENV   ocm_container_custom_version=${GIT_HASH}
