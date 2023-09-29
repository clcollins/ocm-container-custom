OCM_CONTAINER_ORG = "openshift"
OCM_CONTAINER_REPO = "ocm-container"
OCM_CONTAINER_BRANCH = "master"

IMAGE_REPO = "quay.io/app-sre"
IMAGE_NAME = "ocm-container:latest"

UTILS = "github.com:openshift/ops-sop"
TMUX = "github.com:clcollins/tmux-static-builder"
TMUX_IMAGE_REPO = "quay.io/chcollin"
TMUX_IMAGE_NAME = "tmux:latest"

VPN = "Raleigh (RDU2)"

TMPDIR := $(shell mktemp -d /tmp/ocm-container-custom.XXXXX)

CONTAINER_SUBSYS ?= podman

CACHE ?= --no-cache

PULL_BASE_IMAGE ?= TRUE

default: all

.PHONY: all
all: check_env clone build

.PHONY: clone
clone:
	@echo Workdir: $(TMPDIR)
# Note: ifeq must not be indented
ifeq ($(PULL_BASE_IMAGE), FALSE)
	@echo "######## CLONE TMUX BUILDER ########"
	@echo "git@$(TMUX).git"
	@git -C $(TMPDIR) clone --depth=1 git@$(TMUX).git
endif
ifeq ($(PULL_BASE_IMAGE), FALSE)
	@echo "######## CLONE OCM CONTAINER ########"
	@echo "git@github.com:$(OCM_CONTAINER_ORG)/$(OCM_CONTAINER_REPO)"
	@git -C $(TMPDIR) clone --depth=1 --branch $(OCM_CONTAINER_BRANCH) git@github.com:$(OCM_CONTAINER_ORG)/$(OCM_CONTAINER_REPO).git
endif
	@echo "######## CLONE OPS-SOP ########"
	@echo "git@$(UTILS).git"
	@git -C $(TMPDIR) clone --depth=1 git@$(UTILS).git

.PHONY: build
build: build_ocm_container build_tmux build_custom

.PHONY: check_env
check_env:
	@if test -z "${CONTAINER_SUBSYS}" ; then echo 'CONTAINER_SUBSYS must be set. Hint: `source ~/.config/ocm-container/env.source`' ; exit 1 ; fi

.PHONY: build_tmux
build_tmux:
# Note: ifeq must not be indented
ifeq ($(PULL_BASE_IMAGE), FALSE)
	@echo "######## BUILD TMUX ########"
	@pushd $(TMPDIR)/tmux-static-builder && make
else
	@echo "######## PULL TMUX IMAGE ########"
	# quay.io/chcollin/tmux-static-builder:latest
	$(CONTAINER_SUBSYS) pull $(TMUX_IMAGE_REPO)/$(TMUX_IMAGE_NAME)
	$(CONTAINER_SUBSYS) tag $(TMUX_IMAGE_REPO)/$(TMUX_IMAGE_NAME) $(TMUX_IMAGE_NAME)
endif


.PHONY: build_ocm_container
build_ocm_container:
# Note: ifeq must not be indented
ifeq ($(PULL_BASE_IMAGE), FALSE)
	@echo "######## BUILD OCM CONTAINER ########"
	# Don't use the default build.sh script from ocm-container, because it doesn't respect pre-set CONTAINER_SUBSYS env var
	pushd $(TMPDIR)/ocm-container && $(CONTAINER_SUBSYS) build $(CACHE) -t $(IMAGE_NAME) .
else
	@echo "######## PULL OCM CONTAINER ########"
	$(CONTAINER_SUBSYS) pull $(IMAGE_REPO)/$(IMAGE_NAME)
	$(CONTAINER_SUBSYS) tag $(IMAGE_REPO)/$(IMAGE_NAME) $(IMAGE_NAME)
endif

.PHONY: build_custom
build_custom:
	@echo "######## BUILD OCM CUSTOM ########"
	@rsync -azv ./Dockerfile $(TMPDIR)/ops-sop/Dockerfile
	@rsync -azv ./bashrc.d/ $(TMPDIR)/ops-sop/bashrc.d/
	@rsync -azv ./utils/ $(TMPDIR)/ops-sop/v4/utils/
	@pushd $(TMPDIR)/ops-sop/ && ${CONTAINER_SUBSYS} build $(CACHE) -t $(IMAGE_NAME) .
