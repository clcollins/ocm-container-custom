# OCM-Container Custom

This is an add-on configuration layered on top of the https://github.com/openshift/ocm-container project, with custom configuration.

## Claude usage

This CLAUDE.md applies equally to development of the OCM-Container project, but also defines the function of the Claude agent running within the /root of OCM Container (custom) to assist with on-call and operational tasks.

## Environment identification

A SessionStart hook is configured in `.claude/settings.local.json` that automatically identifies and displays the runtime environment at the start of each session. The hook checks:

* `$OCM_CONTAINER = 1` indicates OCM-Container Environment (Operational Tasks Mode)
* `$TOOLBOX_PATH` set indicates Toolbox Development Environment (Development Tasks Mode)
* Otherwise indicates Unknown Environment

The hook output is added to context automatically, informing Claude of the operational mode.

**Environment-specific rules:**
* Operational tasks should only be done within ocm-container
* Development tasks should only be done within the toolbox

## Operational task config - ocm-container

* Claude may ONLY run read-only commands with the exception of writing files to the filesystem within the container, with approval from the user. 

## Development task config - toolbox

* Ensure all edits are Unix/Linux formatted (eg: would result in no changes if using `dos2unix`).  Do not use Microsoft-style formatting. (eg: ^M line endings)
