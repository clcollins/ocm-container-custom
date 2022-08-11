FROM ocm-container:latest
MAINTAINER "Chris Collins <chris.collins@redhat.com>"

# Install TMUX
COPY --from=quay.io/chcollin/tmux-static-builder:latest /tmux /usr/bin/tmux
RUN tmux -V

# Relative to TMPDIR
COPY bashrc.d/* /root/.bashrc.d/
COPY v4/utils /root/utils
