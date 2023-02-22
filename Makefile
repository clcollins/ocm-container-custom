OCM_CONTAINER_ORG = "openshift"
OCM_CONTAINER_REPO = "ocm-container"
OCM_CONTAINER_BRANCH = "master"

BACKPLANE = "gitlab.cee.redhat.com/service/backplane-cli"
UTILS = "github.com:openshift/ops-sop"
TMUX = "github.com:clcollins/tmux-static-builder"

IMAGE_NAME = "ocm-container:latest"

TMPDIR := $(shell mktemp -d /tmp/ocm-container-custom.XXXXX)


CONTAINER_SUBSYS ?= podman

CACHE ?= --no-cache

default: all

.PHONY: all
all: check_env clone build

.PHONY: clone
clone:
	@echo Workdir: $(TMPDIR)
	@echo "######## CLONE TMUX BUILDER ########"
	@echo "git@$(TMUX).git"
	@git -C $(TMPDIR) clone --depth=1 git@$(TMUX).git
	@echo "######## CLONE OCM CONTAINER ########"
	@echo "git@github.com:$(OCM_CONTAINER_ORG)/$(OCM_CONTAINER_REPO)"
	@git -C $(TMPDIR) clone --depth=1 --branch $(OCM_CONTAINER_BRANCH) git@github.com:$(OCM_CONTAINER_ORG)/$(OCM_CONTAINER_REPO).git
	@echo "######## CLONE BACKPLANE ########"
	@git -C $(TMPDIR) clone --depth=1 https://$(BACKPLANE).git
	@echo "######## CLONE OCM CUSTOM ########"
	@echo "git@$(UTILS).git"
	@git -C $(TMPDIR) clone --depth=1 git@$(UTILS).git

.PHONY: build
build: build_ocm_container build_backplane build_tmux build_custom

.PHONY: check_env
check_env:
	@if test -z "${CONTAINER_SUBSYS}" ; then echo 'CONTAINER_SUBSYS must be set. Hint: `source ~/.config/ocm-container/env.source`' ; exit 1 ; fi

.PHONY: build_tmux
build_tmux:
	@echo "######## BUILD TMUX ########"
	@pushd $(TMPDIR)/tmux-static-builder && make

.PHONY: build_ocm_container
build_ocm_container:
	@echo "######## BUILD OCM CONTAINER ########"
	# Don't use the default build.sh script from ocm-container, because it doesn't respect pre-set CONTAINER_SUBSYS env var
	pushd $(TMPDIR)/ocm-container && ${CONTAINER_SUBSYS} build $(CACHE) -t ocm-container:latest .

.PHONY: build_backplane
build_backplane:
	@echo "######## BUILD BACKPLANE ########"
	@pushd $(TMPDIR)/backplane-cli/hack/ocm-container/ && ${CONTAINER_SUBSYS} build $(CACHE) -t $(IMAGE_NAME) .

.PHONY: build_custom
build_custom:
	@echo "######## BUILD OCM CUSTOM ########"
	@rsync -azv ./Dockerfile $(TMPDIR)/ops-sop/Dockerfile
	@rsync -azv ./bashrc.d/ $(TMPDIR)/ops-sop/bashrc.d/
	@rsync -azv ./utils/ $(TMPDIR)/ops-sop/v4/utils/
	@pushd $(TMPDIR)/ops-sop/ && ${CONTAINER_SUBSYS} build $(CACHE) -t $(IMAGE_NAME) .
