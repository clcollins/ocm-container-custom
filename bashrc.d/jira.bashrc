export JIRA_AUTH_TYPE=bearer
export JIRA_API_TOKEN=$(awk '/jira_token/ {print $2}' ~/.config/osdctl)
