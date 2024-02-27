FROM ocm-container:latest
MAINTAINER "Chris Collins <chris.collins@redhat.com>"

RUN microdnf install --assumeyes openldap-clients

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

# Install Servicelogger
RUN mkdir /servicelogger
WORKDIR /servicelogger
ENV SERVICELOGGER_URL="https://api.github.com/repos/geowa4/servicelogger/releases/latest"
RUN curl -sSLf -O $(curl -sSLf ${SERVICELOGGER_URL} -o - | jq -r '.assets[] | select(.name|test("Linux_x86_64.tar.gz$")) | .browser_download_url')
RUN tar --extract --gunzip --no-same-owner --file *.tar.gz
RUN mv servicelogger /root/.local/bin
WORKDIR /
RUN rm -r /servicelogger
RUN /root/.local/bin/servicelogger version
RUN /root/.local/bin/servicelogger cache-update

# Relative to TMPDIR
COPY bashrc.d/* /root/.bashrc.d/
ENV PATH "$PATH:/root/.cache/servicelogger/ops-sop/v4/utils/"
