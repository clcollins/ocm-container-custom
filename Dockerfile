FROM ocm-container:latest
MAINTAINER "Chris Collins <chris.collins@redhat.com>"

# Install TMUX
RUN dnf install -y tmux \
  && dnf clean-all \
  && rm -rf /var/cache/yum

# Relative to TMPDIR
COPY bashrc.d/* /root/.bashrc.d/
COPY v4/utils /root/utils
