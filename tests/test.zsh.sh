#! /usr/bin/env zsh
source "./includes.sh"
LOGISH_LOG_INFO[name]="test"
ERROR "This is an error message."
TRACE "This is a trace message."
LOGISH_LOG_COMMAND "INFO" "Installing rtx plugins..." "sleep 2 && rtx install -y && exit 1"
LOGISH_LOG_COMMAND "INFO" "Pruning rtx plugins..." rtx prune