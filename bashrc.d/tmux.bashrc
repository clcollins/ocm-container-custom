#!/bin/env bash

if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  exec tmux new-session \; \
    split-window -v -p 30 -c /root/sop 'claude' \; \
    select-pane -t 0 \; \
    set-hook pane-exited 'kill-session'
fi

