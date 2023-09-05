#! /usr/bin/env zsh
source "./includes.sh"
ERROR "This is an error message."
TRACE "This is a trace message."
LOGISH_LOG_COMMAND "INFO" "Installing rtx plugins..." "sleep 2 && rtx install -y"
LOGISH_LOG_COMMAND "INFO" "Pruning rtx plugins..." "rtx prune"