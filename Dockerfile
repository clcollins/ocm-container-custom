FROM ocm-container:latest
MAINTAINER "Chris Collins <chris.collins@redhat.com>"

# Relative to TMPDIR
COPY bashrc.d/* /root/.bashrc.d/
COPY v4/utils /root/utils
