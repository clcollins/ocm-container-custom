FROM ocm-container:latest
MAINTAINER "Chris Collins <chris.collins@redhat.com>"

ARG GIT_HASH="xxxxxxxx"

RUN microdnf install --assumeyes openldap-clients jq tar

# Install TMUX
COPY --from=quay.io/chcollin/tmux:latest /tmux /usr/bin/tmux
RUN tmux -V

# Install GH
RUN mkdir /gh
WORKDIR /gh
ENV GH_URL="https://api.github.com/repos/cli/cli/releases/latest"
RUN curl -sSLf -O $(curl -sSLf ${GH_URL} -o - | jq -r '.assets[] | select(.name|test("linux_amd64.tar.gz$")) | .browser_download_url')
RUN tar --extract --gunzip --no-same-owner --strip-components=2 --file *.tar.gz
RUN mv gh /root/.local/bin
WORKDIR /
RUN rm -r /gh
RUN /root/.local/bin/gh --version

# Relative to TMPDIR
COPY bashrc.d/* /root/.bashrc.d/
COPY utils/* /root/.local/bin
ENV PATH "$PATH:/root/.cache/servicelogger/ops-sop/v4/utils/"

# Install Vault CLI
#COPY repofiles/hashicorp.repo /etc/yum.repos.d/hashicorp.repo
#RUN microdnf install --assumeyes vault

COPY ./bin/oc-dtlogs /usr/local/bin
RUN /bin/bash -c "oc plugin list| grep oc-dtlogs"

LABEL ocm_container_custom_version=${GIT_HASH}
ENV   ocm_container_custom_version=${GIT_HASH}
