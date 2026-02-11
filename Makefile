# IMAGE REGISTRY VARIABLES
REGISTRY_NAME := "quay.io"
AUTHFILE := "${HOME}/.config/quay.io/bot_auth.json"

ORG_NAME := "chcollin"
PARENT_ORG_NAME = "app-sre"

IMAGE_NAME = "ocm-container"
GIT_HASH := "$(shell git rev-parse --short HEAD)"

TAG := ${REGISTRY_NAME}/${ORG_NAME}/${IMAGE_NAME}:${GIT_HASH}
TAG_MICRO := ${REGISTRY_NAME}/${ORG_NAME}/${IMAGE_NAME}-micro:${GIT_HASH}
TAG_LATEST := ${REGISTRY_NAME}/${ORG_NAME}/${IMAGE_NAME}:latest
TAG_MICRO_LATEST := ${REGISTRY_NAME}/${ORG_NAME}/${IMAGE_NAME}-micro:latest
# TAG_LATEST_MINIMAL := ${REGISTRY_NAME}/${ORG_NAME}/${IMAGE_NAME}-minimal:latest

TMUX_IMAGE_NAME = "tmux:latest"
SSM_IMAGE_NAME = "aws-session-manager-plugin:latest"

# GIT REPO VARIABLES
OCM_CONTAINER_ORG = "openshift"
OCM_CONTAINER_REPO = "ocm-container"
OCM_CONTAINER_BRANCH = "master"

UTILS = "github.com:openshift/ops-sop"

TMUX = "github.com:clcollins/tmux-static-builder"
SSM = "github.com:aws/session-manager-plugin"

# VPN
VPN = "Raleigh (RDU2)"

# GENERAL VARIABLES
TMPDIR := $(shell mktemp -d /tmp/ocm-container-custom.XXXXX)
CONTAINER_SUBSYS ?= podman

# BUILD VARIABLES
CACHE ?= --no-cache
PULL_BASE_IMAGE ?= TRUE
ALLOW_DIRTY_CHECKOUT ?= FALSE

# MAKE TARGETS
#
default: all

.PHONY: all
all: isclean check_env clone build tag push

.PHONY: micro
micro: isclean check_env clone_ocm_container build_ocm_container_micro tag_micro push_micro

# Check that the git checkout is not dirty
# ALLOW_DIRTY_CHECKOUT anything other than "false" will skip this
.PHONY: isclean
isclean:
ifneq ($(ALLOW_DIRTY_CHECKOUT), TRUE)
	(test 0 -eq $$(git status --porcelain | wc -l)) || (echo "Local git checkout is not clean, commit changes and try again." >&2 && git --no-pager diff && exit 1)
endif

# Check if the "CONTAINER_SUBSYS" variable is set
.PHONY: check_env
check_env:
	@if test -z "${CONTAINER_SUBSYS}" ; then echo 'CONTAINER_SUBSYS must be set. Hint: `source ~/.config/ocm-container/env.source`' ; exit 1 ; fi

.PHONY: clone
clone: clone_tmux clone_ocm_container clone_ops_sop

.PHONY: clone_tmux
clone_tmux:
ifneq ($(PULL_BASE_IMAGE), TRUE)
	git -C $(TMPDIR) clone --depth=1 git@$(TMUX).git
endif

.PHONY: clone_ocm_container
clone_ocm_container:
ifneq ($(PULL_BASE_IMAGE), TRUE)
	@git -C $(TMPDIR) clone --depth=1 --branch $(OCM_CONTAINER_BRANCH) git@github.com:$(OCM_CONTAINER_ORG)/$(OCM_CONTAINER_REPO).git
endif

.PHONY: clone_ssm
clone_ssm:
ifneq ($(PULL_BASE_IMAGE), TRUE)
	# Need to clone SSM either way, as running the image ensure the build of the bin, not the image itself
	@git -C $(TMPDIR) clone --depth=1 git@$(SSM)
endif

.PHONY: clone_ops_sop
clone_ops_sop:
	@git -C $(TMPDIR) clone --depth=1 git@$(UTILS).git

.PHONY: build
build: build_tmux build_ocm_container build_custom

.PHONY: build_tmux
build_tmux:
ifneq ($(PULL_BASE_IMAGE), TRUE)
	@pushd $(TMPDIR)/tmux-static-builder && make BUILD_ARGS="--build-arg=GITHUB_TOKEN=${GITHUB_TOKEN}"
else
	# podman pull "quay.io"/"chcollin"/"tmux:latest"
	$(CONTAINER_SUBSYS) pull ${REGISTRY_NAME}/${ORG_NAME}/${TMUX_IMAGE_NAME}
	$(CONTAINER_SUBSYS) tag ${REGISTRY_NAME}/${ORG_NAME}/${TMUX_IMAGE_NAME} ${TMUX_IMAGE_NAME}
endif

.PHONY: build_ssm
build_ssm:
ifneq ($(PULL_BASE_IMAGE), TRUE)
	@pushd $(TMPDIR)/session-manager-plugin && $(CONTAINER_SUBSYS) build BUILD_ARGS="--build-arg=GITHUB_TOKEN=${GITHUB_TOKEN}" -f Dockerfile -t ${REGISTRY_NAME}/${ORG_NAME}/${SSM_IMAGE_NAME} .
else
	$(CONTAINER_SUBSYS) pull ${REGISTRY_NAME}/${ORG_NAME}/${SSM_IMAGE_NAME}
	$(CONTAINER_SUBSYS) tag ${REGISTRY_NAME}/${ORG_NAME}/${SSM_IMAGE_NAME} ${SSM_IMAGE_NAME}
endif
	# Do this either way
	@pushd $(TMPDIR)/session-manager-plugin && $(CONTAINER_SUBSYS) run -it --rm --name session-manager-plugin -v $(TMPDIR)/session-manager-plugin:/session-manager-plugin:Z ${REGISTRY_NAME}/${ORG_NAME}/${SSM_IMAGE_NAME} make release

.PHONY: build_ocm_container
build_ocm_container:
ifneq ($(PULL_BASE_IMAGE), TRUE)
	pushd $(TMPDIR)/ocm-container && make BUILD_ARGS="--build-arg=GITHUB_TOKEN=${GITHUB_TOKEN}"
	$(CONTAINER_SUBSYS) tag ${TAG_LATEST} ${IMAGE_NAME}:latest
else
	$(CONTAINER_SUBSYS) pull ${REGISTRY_NAME}/${PARENT_ORG_NAME}/${IMAGE_NAME}:latest
	$(CONTAINER_SUBSYS) tag ${REGISTRY_NAME}/${PARENT_ORG_NAME}/${IMAGE_NAME}:latest ${IMAGE_NAME}:latest
endif

.PHONY: build_ocm_contianer_micro
build_ocm_container_micro:
	pushd $(TMPDIR)/ocm-container && make build-micro BUILD_ARGS="--build-arg=GITHUB_TOKEN=${GITHUB_TOKEN}"
	$(CONTAINER_SUBSYS) tag ${TAG_MICRO_LATEST} ${IMAGE_NAME}-micro:latest

.PHONY: build_custom
build_custom:
	@rsync -azv ./ $(TMPDIR)/ops-sop/
	# @rsync -avz $(TMPDIR)/session-manager-plugin/bin/linux_amd64_plugin/session-manager-plugin $(TMPDIR)/ops-sop/v4/utils/ 
	@pushd $(TMPDIR)/ops-sop/ && ${CONTAINER_SUBSYS} build --build-arg=GITHUB_TOKEN=${GITHUB_TOKEN} --build-arg=GIT_HASH=${GIT_HASH} $(CACHE) -t ${TAG} .

.PHONY: tag
tag:
	$(CONTAINER_SUBSYS) tag ${TAG} ${TAG_LATEST}
	$(CONTAINER_SUBSYS) tag ${TAG} ${IMAGE_NAME}:latest

.PHONY: push
push:
	$(CONTAINER_SUBSYS) push ${TAG} --authfile=$(HOME)/.config/quay.io/bot_auth.json
	$(CONTAINER_SUBSYS) push ${TAG_LATEST} --authfile=$(HOME)/.config/quay.io/bot_auth.json

.PHONY: push_micro
push_micro:
	$(CONTAINER_SUBSYS) push ${TAG_MICRO} --authfile=$(HOME)/.config/quay.io/bot_auth.json
	$(CONTAINER_SUBSYS) push ${TAG_MICRO_LATEST} --authfile=$(HOME)/.config/quay.io/bot_auth.json
.PHONY: pull
pull:
	$(CONTAINER_SUBSYS) pull $(REGISTRY_NAME)/$(ORG_NAME)/$(IMAGE_NAME):latest

# Claude Code version management
.PHONY: update-claude-version
update-claude-version:
	@echo "Fetching latest Claude Code version information..."
	@CLAUDE_GCS_BUCKET="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases" && \
	CLAUDE_PLATFORM="linux-x64" && \
	CLAUDE_VERSION=$$(curl -fsSL "$${CLAUDE_GCS_BUCKET}/latest") && \
	echo "Latest version: $${CLAUDE_VERSION}" && \
	MANIFEST_JSON=$$(curl -fsSL "$${CLAUDE_GCS_BUCKET}/$${CLAUDE_VERSION}/manifest.json") && \
	CLAUDE_CHECKSUM=$$(echo "$${MANIFEST_JSON}" | jq -r ".platforms[\"$${CLAUDE_PLATFORM}\"].checksum") && \
	BUILD_DATE=$$(echo "$${MANIFEST_JSON}" | jq -r ".buildDate") && \
	echo "Checksum: $${CLAUDE_CHECKSUM}" && \
	echo "Build date: $${BUILD_DATE}" && \
	echo "Updating Containerfile..." && \
	sed -i "s/^ARG CLAUDE_VERSION=.*/ARG CLAUDE_VERSION=\"$${CLAUDE_VERSION}\"/" Containerfile && \
	sed -i "s/^ARG CLAUDE_CHECKSUM=.*/ARG CLAUDE_CHECKSUM=\"$${CLAUDE_CHECKSUM}\"/" Containerfile && \
	sed -i "s/# Version .* released .*/# Version $${CLAUDE_VERSION} released $${BUILD_DATE}/" Containerfile && \
	echo "✅ Containerfile updated successfully" && \
	echo "" && \
	echo "Updated values:" && \
	echo "  CLAUDE_VERSION: $${CLAUDE_VERSION}" && \
	echo "  CLAUDE_CHECKSUM: $${CLAUDE_CHECKSUM}" && \
	echo "  BUILD_DATE: $${BUILD_DATE}" && \
	echo "" && \
	echo "Please review the changes with 'git diff Containerfile'"
