#!/usr/bin/env sh

#set -e          # fail on error
#set -o nounset  # fail on unset variables
#set -o pipefail # show errors
#set -v
readonly LOGISH_APPNAME="LOGISH"
readonly LOGISH_VERSION=1.0.0

# Guard
[ -n "${LOGISH_SH+x}" ] && return || readonly LOGISH_SH=1

# Support
if [[ -z $BASH_VERSION ]] && [[ -z $ZSH_VERSION ]]; then
    echo "unsupported"
    return 1
fi

# Maps

declare -gA LOGISH_LEVELS=() 
declare -gA LOGISH_PARTS=()

# Default Levels

# Default Parts
declare -gf part_function
declare -gf part_timestamp
declare -gf part_level
declare -gf part_function
declare -gf part_filename
declare -gf part_lineno
declare -gf part_message

# Default Spinner

LOGISH_DEFAULT_TEMPLATE="${LOGISH_DEFAULT_TEMPLATE:-":timestamp: :level: [:function:::lineno:] :message:"}"
LOGISH_DEFAULT_TIME_FORMAT="${LOGISH_DEFAULT_TIME_FORMAT:-"%I:%M%p"}"

# --- internal functions ----------------------------------------------

function LOGISH_split() {
  local delimiter=${1}
  local string="${@:2}"
  if [[ -n $BASH_VERSION ]]; then
    IFS=',' read -r -a result < <(echo "${string}")
  elif [[ -n $ZSH_VERSION ]]; then
    IFS=',' read -r -A result < <(echo "${string}")
  fi
  
  echo ${result[*]}
}

function LOGISH_get_reference() {
  local var_name=$1
  local reference_variable=$2
  
  if [[ -n $BASH_VERSION ]]; then
    echo "local -n ${var_name}=${reference_variable}"
  elif [[ -n $ZSH_VERSION ]]; then
    echo "local -A ${var_name}=(\"\${(kv@)${reference_variable}}\")"
  fi
}

function LOGISH_add_part() {
  local reference=${1}
  eval $(LOGISH_get_reference "part" ${reference})
  
  LOGISH_PARTS+=(["${part[name]}"]="${reference}") 
}

function LOGISH_get_part_ref() {  
  local name=${1}
  local reference=${LOGISH_PARTS[$name]}
  if [[ -n ${reference} ]]; then
    echo ${reference}
  fi
}

function LOGISH_add_level() {
  local level_ref=${1}
  eval $(LOGISH_get_reference "level" ${level_ref}) 
  
  declare -gf ${level[name]}
  eval "${level[name]}() { LOGISH_print_message ${level[name]} \"\${@}\"; }"
  
  LOGISH_LEVELS+=(["${level[name]}"]="${level_ref}")
}

function LOGISH_get_level_ref() {
  local name=${1}
  local reference=${LOGISH_LEVELS[$name]}
  if [[ -n ${reference} ]]; then
    echo ${reference}
  fi
} 

function LOGISH_convert_message_template() {
  local level_ref=$(LOGISH_get_level_ref ${1}); shift
  local message=${*:-}
  eval $(LOGISH_get_reference "level" ${level_ref}) 
  
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
      eval $(LOGISH_get_reference "part" "${part_ref}")
    
      local part_args=( $(LOGISH_split "," ${part[function_args]}) )
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

# --- part definitions ----------------------------------------------
 
declare -A PART_TIMESTAMP=(
  [name]="timestamp"
  [function_name]="part_timestamp"
  [function_args]="format"
  [arg_format]="${LOGISH_DEFAULT_TIME_FORMAT}"
)
part_timestamp() {
  local log_name=${1}
  local log_color=${2}
  local time_format=${3}
  local result=$(date +"${time_format}")
  echo "${result}"
}
LOGISH_add_part "PART_TIMESTAMP"

declare -A PART_LEVEL=(
  [name]="level"
  [function_name]="part_level"
  [function_args]="format"
  [arg_format]="%-8s"
)
part_level() {
  local log_name=${1}
  local log_color=${2}
  local level_format=${3}
  echo "\e[1;${log_color}m$(printf ${level_format} ${log_name})\e[0m"
}
LOGISH_add_part "PART_LEVEL"

declare -A PART_FUNCTION=(
  [name]="function"
  [function_name]="part_function"
)
part_function() {
  local log_name=${1}
  local log_color=${2}
  local function_name=""
  if [[ -n $BASH_VERSION ]]; then
    local parts="${#FUNCNAME[@]}"
    function_name="${FUNCNAME[-1]}"
  elif [[ -n $ZSH_VERSION ]]; then
    function_name="${funcfiletrace[-1]}"
  fi
  echo "${function_name}"
}
LOGISH_add_part "PART_FUNCTION"

declare -A PART_FILENAME=(
  [name]="filename"
  [function_name]="part_filename"
)
part_filename() {
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
LOGISH_add_part "PART_FILENAME"

declare -A PART_LINENO=(
  [name]="lineno"
  [function_name]="part_lineno"
)
part_lineno() {
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
LOGISH_add_part "PART_LINENO"

declare -A PART_MESSAGE=(
  [name]="message"
  [function_name]="part_message"
)
part_message() {
  local log_name=${1}
  local log_color=${2}
  local message=${@:3}
  echo "${message}"
}
LOGISH_add_part "PART_MESSAGE" 

# --- spinner definition ----------------------------------------------

declare -f spinner
declare -A SPINNER=(
  [pid]=""
  [function_start]="spinner_start"
  [function_end]="spinner_end"
  [chars]="◐,◓,◑,◒"
)
spinner_start() {
  local steps=( $(LOGISH_split "," ${SPINNER[chars]}) )
  local t=${#steps[@]}
  local i=0
  local n=$((t - 1))
  
  trap 'spinner_end; return' SIGINT 
  trap 'spinner_end; return' SIGHUP SIGTERM
  
  printf '  '
  while true; do
    local step=${steps[@]:$i:1}
    #echo "step[${step}]"
    echo -en "\033[1D${step}"
    ((i++)) 
    if [[ "$i" > "$n" ]]; then 
      i=0 
    fi 
    sleep 0.2 
  done
}
spinner_end() {
  printf "\033[1D"
  kill ${SPINNER[pid]} &>/dev/null
  SPINNER[pid]=""
}

# --- level definitions ----------------------------------------------

declare -A LOG_FATAL=(
  [code]=100  
  [name]="FATAL"  
  [template]="${LOGISH_FATAL_TEMPLATE:-$LOGISH_DEFAULT_TEMPLATE}"  
  [color]="41"
) 
LOGISH_add_level "LOG_FATAL" 

declare -A LOG_ERROR=(
  [code]=200  
  [name]="ERROR"  
  [template]="${LOGISH_ERROR_TEMPLATE:-$LOGISH_DEFAULT_TEMPLATE}"  
  [color]="31"
) 
LOGISH_add_level "LOG_ERROR" 

declare -A LOG_WARN=(
  [code]=300   
  [name]="WARN"   
  [template]="${LOGISH_WARN_TEMPLATE:-$LOGISH_DEFAULT_TEMPLATE}"   
  [color]="33"
) 
LOGISH_add_level "LOG_WARN" 

declare -A LOG_NOTICE=(
  [code]=400 
  [name]="NOTICE"
  [template]="${LOGISH_NOTICE_TEMPLATE:-$LOGISH_DEFAULT_TEMPLATE}" 
  [color]=33
) 
LOGISH_add_level "LOG_NOTICE" 

declare -A LOG_INFO=(
  [code]=500   
  [name]="INFO"   
  [template]="${LOGISH_INFO_TEMPLATE:-$LOGISH_DEFAULT_TEMPLATE}"   
  [color]="37"
)
LOGISH_add_level "LOG_INFO" 

declare -A LOG_DEBUG=(
  [code]=600  
  [name]="DEBUG"  
  [template]="${LOGISH_DEBUG_TEMPLATE:-$LOGISH_DEFAULT_TEMPLATE}"   
  [color]="34"
) 
LOGISH_add_level "LOG_DEBUG" 

declare -A LOG_TRACE=(
  [code]=700  
  [name]="TRACE"  
  [template]="${LOGISH_TRACE_TEMPLATE:-$LOGISH_DEFAULT_TEMPLATE}"   
  [color]="94"
)
LOGISH_add_level "LOG_TRACE"

# --- helper functions ----------------------------------------------

function LOG_COMMAND() {
    local level_name=${1}
    local message=${2}
    local command_string=${*:3}
    local converted=$(LOGISH_print_message "${level_name}" ${message})
    echo -ne ${converted}
    
    spinner_start &
    SPINNER[pid]="${!}"
    
    eval ${command_string} &>/dev/null &
    wait ${!} >/dev/null

    spinner_end
    echo "[OK]"
}