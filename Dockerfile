# Install GH
FROM registry.access.redhat.com/ubi9/ubi-minimal:9 as builder
RUN microdnf install --assumeyes jq tar gzip
RUN mkdir /gh
WORKDIR /gh
ENV GH_URL="https://api.github.com/repos/cli/cli/releases/latest"
RUN curl -sSLf -O $(curl -sSLf ${GH_URL} -o - | jq -r '.assets[] | select(.name|test("linux_amd64.tar.gz$")) | .browser_download_url')
RUN tar --extract --gunzip --no-same-owner --strip-components=2 --file *.tar.gz

FROM ocm-container:latest 
MAINTAINER "Chris Collins <chris.collins@redhat.com>"

ARG GIT_HASH="xxxxxxxx"

RUN microdnf install --assumeyes openldap-clients jq tar gzip

# Install TMUX
COPY --from=quay.io/chcollin/tmux:latest /tmux ${BIN_DIR}
RUN tmux -V

# Install GH
COPY --from=builder /gh/gh ${BIN_DIR}
RUN gh --version

# Relative to TMPDIR
RUN mkdir -p /root/.bashrc.d
COPY bashrc.d/* /root/.bashrc.d/

RUN mkdir -p /root/.local/bin
COPY utils/* /root/.local/bin
ENV PATH "$PATH:/root/.cache/servicelogger/ops-sop/v4/utils/"

# Install Vault CLI
#COPY repofiles/hashicorp.repo /etc/yum.repos.d/hashicorp.repo
#RUN microdnf install --assumeyes vault

COPY ./bin/oc-dtlogs /usr/local/bin
RUN /bin/bash -c "oc plugin list| grep oc-dtlogs"

LABEL ocm_container_custom_version=${GIT_HASH}
ENV   ocm_container_custom_version=${GIT_HASH}
