# OCM-Container Custom
#
# Structured multi-stage build layered on top of the upstream ocm-container
# image. Modeled on the toolbox-devtools Containerfile:
#   * A single shared `base` stage that all builder stages inherit from.
#   * One isolated builder stage per tool that needs compiling/fetching.
#   * Package repositories constructed INLINE via `dnf config-manager addrepo`
#     (no COPY'd .repo files) so all repo config lives in this file.
#   * A single accumulated `$PKGS` list, declared next to the repo that
#     provides each package.
#   * One consolidated `dnf install $PKGS` in the final stage, with weak deps
#     and docs disabled to keep the image small.

# ---------------------------------------------------------------------------
# Shared base
# ---------------------------------------------------------------------------
# Every builder that starts from the ocm-container image inherits from this
# single alias so the base reference (and any future shared setup) lives in
# one place.
FROM quay.io/redhat-services-prod/openshift/ocm-container:latest AS base

# ---------------------------------------------------------------------------
# tmux builder
# ---------------------------------------------------------------------------
# tmux is not available in the UBI repos without RHEL entitlements, so build
# it from source and copy just the resulting binary into the final image.
FROM base AS tmux-builder

ARG TMUX_VERSION="3.5a"
ARG TMUX_SHA256="16216bd0877170dfcc64157085ba9013610b12b082548c7c9542cc0103198951"

RUN dnf install --assumeyes --nodocs \
        autoconf \
        automake \
        gcc \
        libevent-devel \
        make \
        ncurses-devel \
    && dnf clean all \
    && rm --recursive --force /var/cache/yum

WORKDIR /build
RUN curl --silent --location --fail \
        "https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz" \
        --output tmux.tar.gz \
    && echo "${TMUX_SHA256}  tmux.tar.gz" | sha256sum --check --status \
    && tar --extract --gzip --file tmux.tar.gz \
    && ln --symbolic /usr/bin/true /usr/local/bin/yacc \
    && cd "tmux-${TMUX_VERSION}" \
    && ./configure --prefix=/usr \
    && make -j "$(nproc)" \
    && make install DESTDIR=/build/out \
    && strip --strip-all /build/out/usr/bin/tmux

# ---------------------------------------------------------------------------
# GitHub CLI builder
# ---------------------------------------------------------------------------
FROM base AS gh-builder

# GITHUB_TOKEN (passed by the Makefile's build_custom target) is used to
# authenticate the GitHub API call below and avoid anonymous rate limits.
ARG GITHUB_TOKEN

RUN dnf install --assumeyes jq tar gzip \
    && dnf clean all \
    && rm --recursive --force /var/cache/yum

RUN mkdir /gh
WORKDIR /gh
ARG BIN_URL="https://api.github.com/repos/cli/cli/releases/latest"
ARG BIN_SELECTOR='linux_amd64.tar.gz$'
ARG BIN_ASSET="gh.tar.gz"
RUN curl -o ${BIN_ASSET} -sSLf -O $(curl -sSLf ${GITHUB_TOKEN:+--header "Authorization: Bearer ${GITHUB_TOKEN}"} ${BIN_URL} -o - | jq -r --arg SELECTOR "$BIN_SELECTOR" '.assets[] | select(.name|test($SELECTOR)) | .browser_download_url')
RUN tar --extract --gunzip --no-same-owner --strip-components=2 --file ${BIN_ASSET}

# ---------------------------------------------------------------------------
# Claude Code builder
# ---------------------------------------------------------------------------
FROM base AS claude-builder

# Version 2.1.204 released 2026-07-08
ARG CLAUDE_VERSION="2.1.204"
ARG CLAUDE_CHECKSUM="c8ee1ea69154533c691a68f46abb645196fe7339d26e6fc204cc7f08220139d3"
ARG CLAUDE_PLATFORM="linux-x64"
ARG CLAUDE_GCS_BUCKET="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

# Download and verify Claude Code binary
ADD ${CLAUDE_GCS_BUCKET}/${CLAUDE_VERSION}/${CLAUDE_PLATFORM}/claude /tmp/claude
RUN echo "${CLAUDE_CHECKSUM}  /tmp/claude" | sha256sum --check --status \
    && chmod +x /tmp/claude

# ---------------------------------------------------------------------------
# MCP servers builder
# ---------------------------------------------------------------------------
FROM golang:1.26 AS mcp-builder

# Install shim-mcp (pure Go, no CGO)
RUN go install github.com/clcollins/shim-mcp/cmd/shim-mcp@latest

# Install mnemo (requires CGO for sqlite)
RUN CGO_ENABLED=1 go install github.com/clcollins/mnemo/cmd/mnemo@latest

# ---------------------------------------------------------------------------
# Python tooling builder
# ---------------------------------------------------------------------------
# rh-aws-saml-login and httpie are installed via pip into a self-contained
# virtualenv here so the compilers and -devel headers they need to build
# native extensions (requests-gssapi -> krb5, cffi, etc.) do NOT end up in
# the final image.
#
# The venv is copied to the same path in the final stage. For it to work at
# runtime the final image must provide:
#   * the matching python3 interpreter (same minor version)
#   * krb5-libs (runtime Kerberos libs for requests-gssapi)
# Both are included in $PKGS in the final stage.
#
# NOTE / REVERT PATH: If the copied venv misbehaves at runtime (e.g. Python
# minor-version drift between this builder and the final base, or a missing
# shared library), revert to installing these packages directly in the final
# stage. To do that:
#   1. Delete this pip-builder stage and the `COPY --from=pip-builder` line.
#   2. Add clang, krb5-devel, python3-devel back to $PKGS in the final stage.
#   3. Re-add a final-stage step:
#        RUN python3 -m pip install rh-aws-saml-login httpie
FROM base AS pip-builder

RUN dnf install --assumeyes --setopt=install_weak_deps=False --nodocs \
        clang \
        gcc \
        krb5-devel \
        python3 \
        python3-devel \
        python3-pip \
    && dnf clean all \
    && rm --recursive --force /var/cache/yum

RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/venv/bin/pip install --no-cache-dir rh-aws-saml-login httpie

# ---------------------------------------------------------------------------
# Final image
# ---------------------------------------------------------------------------
FROM base
LABEL maintainer="Chris Collins <chris.collins@redhat.com>"

ARG BIN_DIR="/usr/local/bin"
ARG GIT_HASH="xxxxxxxx"

# Base packages (available from the ocm-container UBI repos).
# nodejs-npm is intentionally omitted (claude ships its own runtime).
# openldap-clients provides ldapsearch; tar/gzip/jq are general tooling used
# by utils and skills. yq is intentionally NOT listed: the upstream base image
# already ships it at /usr/local/bin/yq (it is not a dnf package here).
ENV PKGS="openldap-clients jq tar gzip unzip"

# krb5-libs is the RUNTIME Kerberos lib needed by the pip-built
# requests-gssapi (see pip-builder). python3 provides the interpreter the
# copied venv shebangs point at.
ENV PKGS="${PKGS} krb5-libs python3"

# --- Google Cloud CLI --------------------------------------------------------
# Repository: https://cloud.google.com/sdk/docs/install#rpm
# RHEL 10 base: use the el10 repo and the v10 signing key. repo_gpgcheck is
# disabled to match Google's published el10 configuration (package signatures
# are still verified via gpgcheck=1).
ENV GCLOUD_CLI="https://packages.cloud.google.com/yum/repos/cloud-sdk-el10-x86_64"
ENV GCLOUD_CLI_REPO_NAME="google-cloud-cli"
ENV GCLOUD_KEY="https://packages.cloud.google.com/yum/doc/rpm-package-key-v10.gpg"
# libxcrypt-compat is required by google-cloud-cli on RHEL 10.
ENV PKGS="${PKGS} libxcrypt-compat google-cloud-cli"

# --- Charm (glow) ------------------------------------------------------------
ENV CHARM_REPO="https://repo.charm.sh/yum/"
ENV CHARM_REPO_NAME="charm"
ENV CHARM_KEY="https://repo.charm.sh/yum/gpg.key"
ENV PKGS="${PKGS} glow"

# --- HashiCorp (vault) -------------------------------------------------------
# Installed from the HashiCorp RHEL repo (matches the toolbox-devtools model)
# rather than a pinned binary download. $releasever resolves to 10 on this
# base. openbao* also provide a `vault` binary and conflict, so exclude them
# at install time (see the final dnf install).
ENV VAULT_REPO="https://rpm.releases.hashicorp.com/RHEL/\$releasever/\$basearch/stable"
ENV VAULT_REPO_NAME="hashicorp"
ENV VAULT_KEY="https://rpm.releases.hashicorp.com/gpg"
ENV PKGS="${PKGS} vault"

# --- OpenShell ---------------------------------------------------------------
# OpenShell is only distributed as an RPM (no repo), so it cannot follow the
# inline-repo model. Copy the prebuilt RPM from the toolbox-devtools image and
# add its local path to $PKGS so it installs in the same consolidated step.
COPY --from=quay.io/chcollin/toolbox-devtools:latest /tmp/openshell.rpm /tmp/openshell.rpm
ENV PKGS="${PKGS} /tmp/openshell.rpm"

# Add all third-party repositories and import their signing keys.
#
# NOTE: the ocm-container RHEL 10 base ships dnf4-style `config-manager`,
# which has NO `addrepo` subcommand (that is dnf5, used by the Fedora-based
# toolbox-devtools image). To still "construct the repo in the Containerfile"
# rather than COPY a .repo file, the repo definitions are written inline with
# printf. $releasever/$basearch are escaped so dnf (not the build shell)
# expands them.
#
# The crypto policy is relaxed to LEGACY because the gcloud key uses a
# signature RHEL 10's default policy rejects:
# "Policy rejects F09C394C3E1BA8D5: No binding signature".
RUN update-crypto-policies --set LEGACY \
    && dnf install --assumeyes 'dnf-command(config-manager)' \
    && printf '[%s]\nname=%s\nbaseurl=%s\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=0\ngpgkey=%s\n' \
        "${GCLOUD_CLI_REPO_NAME}" "${GCLOUD_CLI_REPO_NAME}" "${GCLOUD_CLI}" "${GCLOUD_KEY}" \
        > /etc/yum.repos.d/${GCLOUD_CLI_REPO_NAME}.repo \
    && printf '[%s]\nname=%s\nbaseurl=%s\nenabled=1\ngpgcheck=1\ngpgkey=%s\n' \
        "${CHARM_REPO_NAME}" "${CHARM_REPO_NAME}" "${CHARM_REPO}" "${CHARM_KEY}" \
        > /etc/yum.repos.d/${CHARM_REPO_NAME}.repo \
    && printf '[%s]\nname=%s\nbaseurl=%s\nenabled=1\ngpgcheck=1\ngpgkey=%s\n' \
        "${VAULT_REPO_NAME}" "${VAULT_REPO_NAME}" "${VAULT_REPO}" "${VAULT_KEY}" \
        > /etc/yum.repos.d/${VAULT_REPO_NAME}.repo \
    && rpm --import "${GCLOUD_KEY}" \
    && rpm --import "${CHARM_KEY}" \
    && rpm --import "${VAULT_KEY}" \
    && dnf clean all \
    && rm --recursive --force /var/cache/yum/

# Single consolidated package install. Weak deps and docs are disabled to keep
# the image small; openbao* are excluded because they conflict with vault.
# No `dnf update` here: the upstream ocm-container base image rebuilds nightly,
# so its packages are already current.
RUN dnf install --assumeyes \
        --setopt=install_weak_deps=False \
        --setopt=tsflags=nodocs \
        --exclude=openbao \
        --exclude=openbao-vault-compat \
        $PKGS \
    && rm --force /tmp/openshell.rpm \
    && dnf clean all \
    && rm --recursive --force /var/cache/yum/

# --- Binaries from builder stages -------------------------------------------
# Install TMUX
COPY --from=tmux-builder /build/out/usr/bin/tmux ${BIN_DIR}/tmux
RUN tmux -V

# Install GH
COPY --from=gh-builder /gh/gh ${BIN_DIR}
RUN gh --version

# Install Claude Code
COPY --from=claude-builder /tmp/claude ${BIN_DIR}/claude
RUN claude install

# Install MCP servers
COPY --from=mcp-builder /go/bin/shim-mcp ${BIN_DIR}/shim-mcp
COPY --from=mcp-builder /go/bin/mnemo ${BIN_DIR}/mnemo

# Install Python tooling (rh-aws-saml-login, httpie) from the prebuilt venv.
# Symlink the entrypoints onto PATH so they behave like system installs.
COPY --from=pip-builder /opt/venv /opt/venv
RUN ln --symbolic --force /opt/venv/bin/rh-aws-saml-login ${BIN_DIR}/rh-aws-saml-login \
    && ln --symbolic --force /opt/venv/bin/http ${BIN_DIR}/http \
    && ln --symbolic --force /opt/venv/bin/https ${BIN_DIR}/https \
    && rh-aws-saml-login --help > /dev/null \
    && http --version

# --- Runtime configuration ---------------------------------------------------
# Relative to TMPDIR
RUN mkdir -p /root/.bashrc.d
COPY bashrc.d/* /root/.bashrc.d/

RUN mkdir -p /root/.local/bin
COPY utils/* /root/.local/bin

# Tmux configuration
COPY .tmux.conf /root/.tmux.conf

ENV CLAUDE_PROMPT="You are in an OCM Container. Summarize what you know about this PagerDuty Incident from the ENV variables, cluster context, service logs and SOPs."

LABEL ocm_container_custom_version=${GIT_HASH}
ENV   ocm_container_custom_version=${GIT_HASH}
