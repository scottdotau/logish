#! /usr/bin/env zsh
source "./includes.sh"
ERROR "This is an error message."
TRACE "This is a trace message."
LOG_COMMAND "WARN" "Run a command" "sleep 2 && docker ps"