#!/usr/bin/env bash
# Automatically display cluster context at login using osdctl

# Only run if CLUSTER_ID is set and SKIP_CLUSTER_CONTEXT is not set
if [ -z "$CLUSTER_ID" ] || [ -n "$SKIP_CLUSTER_CONTEXT" ]; then
	return
fi

# Don't run in Claude Code sessions to avoid slowing down the CLI
if [ -n "$CLAUDECODE" ]; then
	return
fi

# Only run if we're in an active tmux session
if [ -z "$TMUX" ]; then
	return
fi

# Create lockfile path based on cluster ID to ensure one-time execution per cluster
LOCKFILE="/tmp/osdctl-cluster-context-${CLUSTER_ID}.flag"

# Skip if lockfile exists - context has already been displayed for this cluster
if [ -f "$LOCKFILE" ]; then
	return
fi

# Create lockfile to prevent future invocations for this cluster
touch "$LOCKFILE"

# Display cluster context information
osdctl cluster context --cluster-id "$CLUSTER_ID"

