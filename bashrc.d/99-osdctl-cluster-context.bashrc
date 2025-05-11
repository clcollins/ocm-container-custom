#!/usr/bin/env bash
# show cluster context at login

if [ -n "$CLUSTER_ID" -a -z "$SKIP_CLUSTER_CONTEXT" ]; then
	if ! ( type tmux >/dev/null 2>/dev/null && [ -n "$TMUX" ] ) ; then
	  # Tmux is installed but not running yet ; don't gather context
	  return
	fi

	echo "Checking the context on $CLUSTER_ID"
	osdctl cluster context --cluster-id "$CLUSTER_ID"
fi
