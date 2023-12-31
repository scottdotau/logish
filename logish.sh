#!/usr/bin/env sh

#set -e          # fail on error
#set -o nounset  # fail on unset variables
#set -o pipefail # show errors
#set -vx         # debugging

readonly LOGISH_APPNAME="LOGISH"
readonly LOGISH_VERSION="1.0.0"

# Support
[[ -z $BASH_VERSION && -z $ZSH_VERSION ]] && return 1

LOGISH_DEFAULT_TEMPLATE="${LOGISH_DEFAULT_TEMPLATE:-":timestamp: :level: [:filename:::lineno:] :message:"}"
LOGISH_DEFAULT_TIME_FORMAT="${LOGISH_DEFAULT_TIME_FORMAT:-"%I:%M%p"}"

# Maps
declare -gA LOGISH_LEVELS=() 
declare -gA LOGISH_PARTS=()

# Default Levels
declare -gA LOGISH_LOG_FATAL
declare -gA LOGISH_LOG_ERROR
declare -gA LOGISH_LOG_WARN
declare -gA LOGISH_LOG_NOTICE
declare -gA LOGISH_LOG_INFO
declare -gA LOGISH_LOG_DEBUG
declare -gA LOGISH_LOG_TRACE

# Default Parts
declare -gA LOGISH_PART_LEVEL
declare -gA LOGISH_PART_TIMESTAMP
declare -gA LOGISH_PART_FUNCTION
declare -gA LOGISH_PART_FILENAME
declare -gA LOGISH_PART_LINENO
declare -gA LOGISH_PART_MESSAGE

# Default Spinner
declare -gA LOGISH_SPINNER

# --- level definitions -

LOGISH_LOG_FATAL=(
  [code]=100  
  [name]="FATAL"  
  [template]="${LOGISH_FATAL_TEMPLATE:-$LOGISH_DEFAULT_TEMPLATE}"  
  [color]="41"
) 

LOGISH_LOG_ERROR=(
  [code]=200  
  [name]="ERROR"  
  [template]="${LOGISH_ERROR_TEMPLATE:-$LOGISH_DEFAULT_TEMPLATE}"  
  [color]="31"
) 

LOGISH_LOG_WARN=(
  [code]=300   
  [name]="WARN"   
  [template]="${LOGISH_WARN_TEMPLATE:-$LOGISH_DEFAULT_TEMPLATE}"   
  [color]="33"
) 

LOGISH_LOG_NOTICE=(
  [code]=400 
  [name]="NOTICE"
  [template]="${LOGISH_NOTICE_TEMPLATE:-$LOGISH_DEFAULT_TEMPLATE}" 
  [color]=33
) 

LOGISH_LOG_INFO=(
  [code]=500   
  [name]="INFO"   
  [template]="${LOGISH_INFO_TEMPLATE:-$LOGISH_DEFAULT_TEMPLATE}"   
  [color]="37"
)

LOGISH_LOG_DEBUG=(
  [code]=600  
  [name]="DEBUG"  
  [template]="${LOGISH_DEBUG_TEMPLATE:-$LOGISH_DEFAULT_TEMPLATE}"   
  [color]="34"
) 

LOGISH_LOG_TRACE=(
  [code]=700  
  [name]="TRACE"  
  [template]="${LOGISH_TRACE_TEMPLATE:-$LOGISH_DEFAULT_TEMPLATE}"   
  [color]="94"
)

# --- part definitions -
 

LOGISH_PART_LEVEL=(
  [name]="level"
  [function_name]="logish_part_level"
  [function_args]="format"
  [arg_format]="%-8s"
)
logish_part_level() {
  local log_name=${1}
  local log_color=${2}
  local level_format=${3}
  echo "\e[1;${log_color}m$(printf ${level_format} ${log_name})\e[0m"
}

LOGISH_PART_TIMESTAMP=(
  [name]="timestamp"
  [function_name]="logish_part_timestamp"
  [function_args]="format"
  [arg_format]="${LOGISH_DEFAULT_TIME_FORMAT}"
)
logish_part_timestamp() {
  local log_name=${1}
  local log_color=${2}
  local time_format=${3}
  local result=$(date +"${time_format}")
  echo "${result}"
}

LOGISH_PART_FUNCTION=(
  [name]="function"
  [function_name]="logish_part_function"
)
logish_part_function() {
  local log_name=${1}
  local log_color=${2}
  local function_name=""
  if [[ -n $BASH_VERSION ]]; then
    function_name="${FUNCNAME[-1]}"
  elif [[ -n $ZSH_VERSION ]]; then
    local fname=(${(s/:/)funcfiletrace[-1]})
    function_name="${fname[1]}"
  fi
  echo "${function_name}"
}

LOGISH_PART_FILENAME=(
  [name]="filename"
  [function_name]="logish_part_filename"
)
logish_part_filename() {
  local log_name=${1}
  local log_color=${2}
  local filename_name=""
  if [[ -n $BASH_VERSION ]]; then
    filename_name="$(basename ${BASH_SOURCE[4]})" 
  elif [[ -n $ZSH_VERSION ]]; then
    filename_name="$(basename ${funcfiletrace[5]%:*})"
  fi
  echo "${filename_name}"
}

LOGISH_PART_LINENO=(
  [name]="lineno"
  [function_name]="logish_part_lineno"
)
logish_part_lineno() {
  local log_name=${1}
  local log_color=${2}
  local lineno=""
  if [[ -n $BASH_VERSION ]]; then
    lineno="${BASH_LINENO[3]}"
  elif [[ -n $ZSH_VERSION ]]; then
    lineno="${funcfiletrace[5]##*:}"
  fi
  echo "${lineno}"
}

LOGISH_PART_MESSAGE=(
  [name]="message"
  [function_name]="logish_part_message"
)
logish_part_message() {
  local log_name=${1}
  local log_color=${2}
  local message=${@:3}
  echo "${message}"
}

# --- spinner definition -

LOGISH_SPINNER=(
  [pid]=""
  [function_start]="logish_spinner_start"
  [function_end]="logish_spinner_end"
  [chars]="◐,◓,◑,◒"
)
logish_spinner_start() {
  local steps=( $(__split "," ${LOGISH_SPINNER[chars]}) )
  local t=${#steps[@]}
  local i=0
  local n=$((t - 1))
  
  trap 'logish_spinner_end; return' SIGINT 
  trap 'logish_spinner_end; return' SIGHUP SIGTERM
  
  printf '  '
  while true; do
    echo -en "\033[1D${steps[@]:$i:1}"
    ((i++)) 
    if [[ "$i" > "$n" ]]; then 
      i=0 
    fi 
    sleep 0.2 
  done
}
logish_spinner_end() {
  printf "\033[1D"
  [[ -n ${LOGISH_SPINNER[pid]} ]] && kill ${LOGISH_SPINNER[pid]} &>/dev/null
  LOGISH_SPINNER[pid]=""
} 

# --- internal functions -

function __split() {
  local delimiter=${@:1:1}
  local string="${@:2}"
  if [[ -n $BASH_VERSION ]]; then
    IFS="${delimiter}" read -r -a result < <(echo "${string}")
  elif [[ -n $ZSH_VERSION ]]; then
    IFS="${delimiter}" read -r -A result < <(echo "${string}")
  fi
  echo "${result[@]}"
}

function __get_reference() {
  local var_name=${@:1:1}
  local reference_variable=${@:2:1}
  
  if [[ -n $BASH_VERSION ]]; then
    echo "local -n ${var_name}=${reference_variable}"
  elif [[ -n $ZSH_VERSION ]]; then
    echo "local -A ${var_name}=(\"\${(kv@)${reference_variable}}\")"
  fi
}

function LOGISH_add_part() {
  local reference=${1}
  eval $(__get_reference "part" ${reference})
  
  LOGISH_PARTS+=(["${part[name]}"]="${reference}") 
}

function LOGISH_get_part_ref() {  
  local part_name=${@:1}
  local part_ref=${LOGISH_PARTS[$part_name]}
  [[ -n ${part_ref} ]] && echo "${part_ref}"
}

function LOGISH_add_level() {
  local level_ref=${@:1}
  eval $(__get_reference "level" ${level_ref}) 
  
  eval "${level[name]}() { LOGISH_print_message ${level[name]} \"\${@}\"; }"
  declare -g ${level[name]}
  
  LOGISH_LEVELS+=(["${level[name]}"]="${level_ref}")
}

function LOGISH_get_level_ref() {
  local level_name=${@:1}
  local level_ref=${LOGISH_LEVELS[$level_name]}
  [[ -n ${level_ref} ]] && echo "${level_ref}"
} 

function LOGISH_convert_message_template() {
  local level_ref=$(LOGISH_get_level_ref ${1});
  local message=${*:2}
  eval $(__get_reference "level" ${level_ref}) 
  
  local converted=${level[template]}
  while [[ "${converted}" =~ :[a-z]+: ]]; do
    local -a fargs
    fargs=()
    fargs+=( "${level[name]}" )
    fargs+=( "${level[color]}" )  
    
    if [[ -n $BASH_VERSION ]]; then
      local part_tag="${BASH_REMATCH[0]}"
    elif [[ -n $ZSH_VERSION ]]; then
      local part_tag="${MATCH}"
    fi
    
    local part_name=${part_tag//:}
    local part_ref=$(LOGISH_get_part_ref "${part_name}")
    
    if [[ -n ${part_ref} ]]; then
      eval $(__get_reference "part" "${part_ref}")
    
      local part_args=( $(__split "," ${part[function_args]}) )
      for varg in "${part_args[@]}"; do
        [[ -z ${varg} ]] && break
        local found_arg=$(echo "arg_${varg}" | tr -d "\n")
        fargs+=(${part[$found_arg]})
      done
      
      if [[ "${part[name]}" == "message" ]]; then
        fargs+=(${message})
      fi
    fi
    
    converted="${converted/${part_tag}/$(eval ${part[function_name]} "${fargs[*]}")}"
  done
  echo "${converted}"
}

function LOGISH_print_message() {
  local level_name=${1}; shift
  local level_ref=$(LOGISH_get_level_ref ${level_name})
  local message=${*:-}
  
  if [[ -z ${level_ref} ]]; then
    return 1
  fi
  
  local line=$(LOGISH_convert_message_template "${level_name}" \
    "${message}")
    
  echo -e "${line}"
} 

# --- helper functions -

LOGISH_LOG_COMMAND() {
    # allow multiple commands passed through as strings, loop through
    local level_name=${@:1:1}
    local message=${@:2:1}
    local command_string=( $(__split " " ${*:3}) )
    local command=${command_string[@]:0:1}
    local command_args=( ${command_string[@]:1} )
    
    local line=$(LOGISH_print_message "${level_name}" ${message})
    echo -n "${line}"
    
    logish_spinner_start &
    LOGISH_SPINNER[pid]="${!}"
    
    eval $command ${command_args[*]} &>/dev/null &
    wait ${!} &>/dev/null

    logish_spinner_end
    echo "[${?} OK]"
}

# --- add defaults - 

LOGISH_add_level "LOGISH_LOG_FATAL" 
LOGISH_add_level "LOGISH_LOG_ERROR" 
LOGISH_add_level "LOGISH_LOG_WARN" 
LOGISH_add_level "LOGISH_LOG_NOTICE" 
LOGISH_add_level "LOGISH_LOG_INFO" 
LOGISH_add_level "LOGISH_LOG_DEBUG" 
LOGISH_add_level "LOGISH_LOG_TRACE" 

LOGISH_add_part "LOGISH_PART_LEVEL" 
LOGISH_add_part "LOGISH_PART_TIMESTAMP" 
LOGISH_add_part "LOGISH_PART_FUNCTION" 
LOGISH_add_part "LOGISH_PART_FILENAME"
LOGISH_add_part "LOGISH_PART_LINENO"
LOGISH_add_part "LOGISH_PART_MESSAGE" 