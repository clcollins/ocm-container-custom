FROM ocm-container:latest
MAINTAINER "Chris Collins <chris.collins@redhat.com>"

# Install TMUX
COPY --from=quay.io/chcollin/tmux:latest /tmux /usr/bin/tmux
RUN tmux -V

# Install GH
RUN mkdir /gh
WORKDIR /gh
ENV GH_URL="https://api.github.com/repos/${GH_URL_SLUG}/releases/${GH_VERSION}"
ENV GH_URL="https://api.github.com/repos/cli/cli/releases/latest"
RUN curl -sSLf -O $(curl -sSLf ${GH_URL} -o - | jq -r '.assets[] | select(.name|test("linux_amd64.tar.gz$")) | .browser_download_url')
RUN tar --extract --gunzip --no-same-owner --strip-components=2 --file *.tar.gz
RUN mv gh /root/.local/bin
WORKDIR /
RUN rm -r /gh
RUN /root/.local/bin/gh --version

# Relative to TMPDIR
COPY bashrc.d/* /root/.bashrc.d/
COPY v4/utils /root/.local/bin
