# Install GH
FROM registry.access.redhat.com/ubi9/ubi-minimal:9.3-1612 as builder
ARG GITHUB_TOKEN
RUN microdnf install --assumeyes jq tar gzip
RUN mkdir /gh
WORKDIR /gh
ENV BIN_URL="https://api.github.com/repos/cli/cli/releases/latest"
ENV BIN_SELECTOR='linux_amd64.tar.gz$'
ENV BIN_ASSET="gh.tar.gz"
RUN curl -o ${BIN_ASSET} -sSLf -O $(curl -sSLf ${BIN_URL} -o - | jq -r --arg SELECTOR "$BIN_SELECTOR" '.assets[] | select(.name|test($SELECTOR)) | .browser_download_url')
RUN tar --extract --gunzip --no-same-owner --strip-components=2 --file ${BIN_ASSET}

RUN mkdir /mirrosa
WORKDIR /mirrosa
ENV BIN_URL="https://api.github.com/repos/mjlshen/mirrosa/releases/latest"
ENV BIN_SELECTOR='linux_amd64$'
ENV BIN_ASSET="mirrosa"
RUN curl -o ${BIN_ASSET} -sSLf -O $(curl -sSLf ${BIN_URL} -o - | jq -r --arg SELECTOR "$BIN_SELECTOR" '.assets[] | select(.name|test($SELECTOR)) | .browser_download_url')
RUN chmod +x ${BIN_ASSET}

FROM quay.io/app-sre/ocm-container:latest
MAINTAINER "Chris Collins <chris.collins@redhat.com>"
ENV BIN_DIR "/usr/local/bin"

ARG GIT_HASH="xxxxxxxx"

RUN microdnf install --assumeyes openldap-clients jq tar gzip

# Install TMUX
COPY --from=quay.io/chcollin/tmux:latest /tmux ${BIN_DIR}
RUN tmux -V

# Install GH
COPY --from=builder /gh/gh ${BIN_DIR}
RUN gh --version

# Install Mirrosa
COPY --from=builder /mirrosa/mirrosa ${BIN_DIR}
RUN mirrosa -h

# Relative to TMPDIR
RUN mkdir -p /root/.bashrc.d
COPY bashrc.d/* /root/.bashrc.d/

RUN mkdir -p /root/.local/bin
COPY utils/* /root/.local/bin
ENV PATH "$PATH:/root/.cache/servicelogger/ops-sop/v4/utils/"

# Install Vault CLI
COPY repofiles/hashicorp.repo /etc/yum.repos.d/hashicorp.repo
RUN microdnf install --assumeyes vault terraform

# Install Google Cloud CLI
COPY repofiles/google-cloud-cli.repo /etc/yum.repos.d/google-cloud-cli.repo
RUN microdnf install --assumeyes google-cloud-cli

#COPY ./bin/oc-dtlogs /usr/local/bin
#RUN /bin/bash -c "oc plugin list| grep oc-dtlogs"

LABEL ocm_container_custom_version=${GIT_HASH}
ENV   ocm_container_custom_version=${GIT_HASH}
