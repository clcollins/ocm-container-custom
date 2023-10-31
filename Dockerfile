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
RUN gh --version
WORKDIR /
RUN rm -r /gh

# Relative to TMPDIR
COPY bashrc.d/* /root/.bashrc.d/
COPY v4/utils /root/.local/bin


# ENV BIN_DIR="/usr/local/bin"
# ENV PATH "/root/.local/bin/backplane/latest:/root.local/bin/:$PATH"
# 
# # Install via backplane-tools
# ARG BACKPLANE_TOOLS_VERSION="tags/v0.0.0"
# ENV BACKPLANE_TOOLS_URL_SLUG="openshift/backplane-tools"
# ENV BACKPLANE_TOOLS_URL="https://api.github.com/repos/${BACKPLANE_TOOLS_URL_SLUG}/releases/${BACKPLANE_TOOLS_VERSION}"
# RUN mkdir /backplane-tools
# WORKDIR /backplane-tools
# 
# # Download the checksum
# RUN /bin/bash -c "curl -sSLf $(curl -sSLf ${BACKPLANE_TOOLS_URL} -o - | jq -r '.assets[] | select(.name|test("checksums.txt")) | .browser_download_url') -o checksums.txt"
# 
# ## amd64
# # Download the binary
# RUN [[ $(platform_convert "@@PLATFORM@@" --amd64 --arm64) != "amd64" ]] && exit 0 || /bin/bash -c "curl -sSLf -O $(curl -sSLf ${BACKPLANE_TOOLS_URL} -o - | jq -r '.assets[] | select(.name|test("linux_amd64")) | .browser_download_url') "
# ## arm64
# # Download the binary
# RUN [[ $(platform_convert "@@PLATFORM@@" --amd64 --arm64) != "arm64" ]] && exit 0 || /bin/bash -c "curl -sSLf -O $(curl -sSLf ${BACKPLANE_TOOLS_URL} -o - | jq -r '.assets[] | select(.name|test("linux_arm64")) | .browser_download_url') "
# 
# # Extract
# RUN tar --extract --gunzip --no-same-owner --directory ${BIN_DIR}  --file *.tar.gz
# 
# # Install all with backplane-tools
# RUN backplane-tools install all
# RUN ln -s /root/.local/bin/backplane/aws/*/aws-cli/dist/aws_completer /root/.local/bin/
# 
# WORKDIR /
