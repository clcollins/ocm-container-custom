OCM_CONTAINER="github.com:openshift/ocm-container"
BACKPLANE="gitlab.cee.redhat.com:service/backplane-cli"
UTILS="github.com:openshift/ops-sop"

IMAGE_NAME="ocm-container:latest"

TMPDIR := $(shell mktemp -d /tmp/ocm-container-custom.XXXXX)

.PHONY: all
all: check_env clone build

.PHONY: clone
clone:
	@echo Workdir: $(TMPDIR)
	@git -C $(TMPDIR) clone --depth=1 git@$(OCM_CONTAINER).git
	@git -C $(TMPDIR) clone --depth=1 git@$(BACKPLANE).git
	@git -C $(TMPDIR) clone --depth=1 git@$(UTILS).git

.PHONY: build
build: build_ocm_container build_backplane build_custom

.PHONY: check_env
check_env:
	@if test -z ${CONTAINER_SUBSYS} ; then echo 'CONTAINER_SUBSYS must be set. Hint: `source ~/.config/ocm-container/env.source`' ; exit 1 ; fi

.PHONY: build_ocm_container
build_ocm_container:
	@pushd $(TMPDIR)/ocm-container && ./build.sh

.PHONY: build_backplane
build_backplane:
	@pushd $(TMPDIR)/backplane-cli/hack/ocm-container/ && ${CONTAINER_SUBSYS} build -t $(IMAGE_NAME) .

.PHONY: build_custom
build_custom:
	@rsync -z ./Dockerfile $(TMPDIR)/ops-sop/Dockerfile
	@pushd $(TMPDIR)/ops-sop/ && ${CONTAINER_SUBSYS} build -t $(IMAGE_NAME) .
