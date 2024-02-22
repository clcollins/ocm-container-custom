OCM_CONTAINER_ORG = "openshift"
OCM_CONTAINER_REPO = "ocm-container"
OCM_CONTAINER_BRANCH = "master"

IMAGE_REPO = "quay.io/app-sre"
IMAGE_NAME = "ocm-container:latest"

UTILS = "github.com:openshift/ops-sop"
TMUX = "github.com:clcollins/tmux-static-builder"
TMUX_IMAGE_REPO = "quay.io/chcollin"
TMUX_IMAGE_NAME = "tmux:latest"

SSM = "github.com:aws/session-manager-plugin"
SSM_IMAGE_REPO = "quay.io/chcollin"
SSM_IMAGE_NAME = "aws-session-manager-plugin"

VPN = "Raleigh (RDU2)"

TMPDIR := $(shell mktemp -d /tmp/ocm-container-custom.XXXXX)

CONTAINER_SUBSYS ?= podman

CACHE ?= --no-cache

PULL_BASE_IMAGE ?= FALSE

default: all

.PHONY: all
all: check_env clone build

.PHONY: clone
clone: clone_tmux clone_ocm_container clone_ops_sop

.PHONY: clone_tmux
clone_tmux:
	@echo Workdir: $(TMPDIR)
# Note: ifeq must not be indented
ifeq ($(PULL_BASE_IMAGE), FALSE)
	@echo "######## CLONE TMUX BUILDER ########"
	@echo "git@$(TMUX).git"
	@git -C $(TMPDIR) clone --depth=1 git@$(TMUX).git
endif

.PHONY: clone_ocm_container
clone_ocm_container:
ifeq ($(PULL_BASE_IMAGE), FALSE)
	@echo "######## CLONE OCM CONTAINER ########"
	@echo "git@github.com:$(OCM_CONTAINER_ORG)/$(OCM_CONTAINER_REPO)"
	@git -C $(TMPDIR) clone --depth=1 --branch $(OCM_CONTAINER_BRANCH) git@github.com:$(OCM_CONTAINER_ORG)/$(OCM_CONTAINER_REPO).git
endif

.PHONY: clone_ssm
clone_ssm:
	# Need to clone SSM either way, as running the image ensure the build of the bin, not the image itself
	@echo "######## CLONE AWS SSM ########"
	@echo "https://$(SSM)"
	@git -C $(TMPDIR) clone --depth=1 git@$(SSM)

.PHONY: clone_ops_sop
clone_ops_sop:
	@echo "######## CLONE OPS-SOP ########"
	@echo "git@$(UTILS).git"
	@git -C $(TMPDIR) clone --depth=1 git@$(UTILS).git

.PHONY: build
build: build_tmux build_ocm_container build_custom

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

.PHONY: build_ssm
build_ssm:
# Note: ifeq must not be indented
ifeq ($(PULL_BASE_IMAGE), FALSE)
	@echo "######## BUILD SSM ########"
	@pushd $(TMPDIR)/session-manager-plugin && $(CONTAINER_SUBSYS) build -f Dockerfile -t $(SSM_IMAGE_REPO)/$(SSM_IMAGE_NAME) .
else
	@echo "######## PULL SSM IMAGE ########"
	$(CONTAINER_SUBSYS) pull $(SSM_IMAGE_REPO)/$(SSM_IMAGE_NAME)
	$(CONTAINER_SUBSYS) tag $(SSM_IMAGE_REPO)/$(SSM_IMAGE_NAME) $(SSM_IMAGE_NAME)
endif
	# Do this either way
	@pushd $(TMPDIR)/session-manager-plugin && $(CONTAINER_SUBSYS) run -it --rm --name session-manager-plugin -v $(TMPDIR)/session-manager-plugin:/session-manager-plugin:Z $(SSM_IMAGE_REPO)/$(SSM_IMAGE_NAME) make release

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
	# @rsync -avz $(TMPDIR)/session-manager-plugin/bin/linux_amd64_plugin/session-manager-plugin $(TMPDIR)/ops-sop/v4/utils/ 
	@pushd $(TMPDIR)/ops-sop/ && ${CONTAINER_SUBSYS} build $(CACHE) -t $(IMAGE_NAME) .
