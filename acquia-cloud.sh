#!/bin/bash

###############################################################
#               Acquia Cloud Utility	               	      #
#               Author: phi.vanngoc@activearkjwt.com          #
###############################################################
VERSION=0.1
REPOS_URL=http://104.131.99.199/acquia-clould-util.sh
INSTALL_PATH=/usr/local/bin/acquia-cloud-util
CREDENTIALS_CACHE_DIR=$HOME/.acquia-cloud-util
DEFAULT_EMAIL_ADDRESS=drupal@activeark.com
API_ENDPOINT=https://cloudapi.acquia.com/v1
COMMAND_FILE_PATH=./acquia-commands.txt
DEFAULT_SITE_NAME=default

CHOSEN_CACHE_FILE=""

SITE_NAME=""
EMAIL_ADDRESS=""
PRIVATE_KEY=""
COMMAND=""
PREPARED_COMMAND_PATH=""

COMMAND_NAMES=()
COMMAND_METHODS=()
COMMAND_DESCS=()
COMMAND_PATHS=()
COMMAND_INDEX=1

# Color codes
txtOff='\e[0m'          # Text Reset
txtBlack='\e[0;30m'     # Black - Regular
txtRed='\e[0;31m'       # Red
txtGreen='\e[0;32m'     # Green
txtYellow='\e[0;33m'    # Yellow
txtBlue='\e[0;34m'      # Blue
txtPurple='\e[0;35m'    # Purple
txtCyan='\e[0;36m'      # Cyan
txtWhite='\e[0;37m'     # White


__print_error()
{
  echo -e "${txtRed}$1${txtOff}"
}

__print_info()
{
  echo -e "${txtGreen}$1${txtOff}"
}

__print_prompt()
{
  echo -e -n "${txtGreen}$1${txtOff} $2"
}

__print_warning()
{
  echo -e "${txtYellow}$1${txtOff}"
}

__prompt_user_input()
{
  local answer
  read -p "$1" answer
  echo $answer
}

__print_command_status()
{
  if [ $? -eq 0 ]; then
    echo -e "${txtGreen}$1: ${txtOff}[ OK ]"
  else
    echo -e "${txtGreen}$1: ${txtOff}[${txtRed} ERROR ${txtOff}]"
  fi
}

__do_self_update()
{
  sudo mv $1 $INSTALL_PATH; [ -f $INSTALL_PATH ]; sudo chmod a+x $INSTALL_PATH; local status=$?
  __print_command_status "Self update"
  [ $status -eq 0 ] && __print_info "You need to relaunch the script, quit now!" && exit
}

__get_new_version()
{
  local tmp_file="/tmp/acquia-cloud-util_$(date +%Y_%m_%d_%H_%M).sh" answer
  curl -o $tmp_file $REPOS_URL 2>/dev/null

  if [ -f $tmp_file ]; then
    local version=$(egrep "VERSION=[0-9\.]+" $tmp_file)
    version=${version#VERSION=}
    [ ! -z "$version" ] && [ "$version" != "$VERSION" ] &&  echo $tmp_file || echo ""
  else
    echo ""
  fi
}

__check_update_requirements()
{
  which curl >/dev/null 2>&1
  return $?
}

__confirm_update()
{
  echo -e -n "${txtGreen}UPDATE:${txtOff} ${txtYellow}There is a new version of the script, do you want to update it now?${txtOff} [y/n] "
  read answer

  case $answer in
    y|Y)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

__check_update()
{
  __check_update_requirements
  local req_status=$?

  [ ! $? -eq 0 ] && [ "$1" == "verbose" ] && __print_error "You dont have curl installed. Please install it first." && exit 1
  [ ! $req_status -eq 0 ] && [ "$1" != "verbose" ] && return 1

  local new_version=$(__get_new_version)
  if [ ! -z "$new_version" ]; then
    __confirm_update && __do_self_update $new_version || [ "$1" == "verbose" ] && exit
  else
    [ "$1" == "verbose" ] && __print_warning "No update available" && exit
  fi
}

__print_usage()
{
  echo "Usage: $0"
}

__print_banner()
{
  echo
  echo -e "${txtWhite}\e[44m#########################################${txtOff}"
  echo -e "${txtWhite}\e[44m#         ACQUIA CLOUD UTILITY          #${txtOff}"
  echo -e "${txtWhite}\e[44m#########################################${txtOff}"
  echo
}

__print_footer()
{
  __print_warning "DONE!"
}

__print_current_version()
{
  echo "Current version: $VERSION" && exit 0
}

__print_cached_credentials()
{
  if [ -d $CREDENTIALS_CACHE_DIR ] && [ ! -z "$(ls $CREDENTIALS_CACHE_DIR)" ]; then
    echo $(__to_uppercase "Cached credentials")
    local labels values

    labels[1]="Email address"
    labels[2]="Key"

    cd $CREDENTIALS_CACHE_DIR

    for file in $(ls $CREDENTIALS_CACHE_DIR); do
      source $file
      values[1]=$EMAIL_ADDRESS
      values[2]=$PRIVATE_KEY

      __print_info "\n$file"

      for (( i=1; i<=${#labels[@]}; i++ )); do
        echo -e "${i}) ${txtYellow}${labels[$i]}${txtOff}: ${txtWhite}${values[$i]}${txtOff}"
      done
    done
    __print_cached_credentials_ops
  else
    __print_warning "There is no items in the cache"
  fi
}

__print_cached_credentials_ops()
{
  __print_info "\nWhat do you want to do with cached credentials?"
  local opts=("Remove the credentials" "Update the credentials" "Nothing (quit)") opt

  select opt in "${opts[@]}"; do
    case $REPLY in
      1)
        __remove_credentials && exit 0
        ;;
      2)
        __update_credentials && exit 0
        ;;
      *)
        exit 0
        ;;
    esac
  done
}

__list_cached_credentials_files()
{
  CHOSEN_CACHE_FILE=""

  local files i=1 j choice
  __print_info "$1. Please select the site"

  for file in $(ls $CREDENTIALS_CACHE_DIR); do
    files[$i]="$file"
    let "i+=1"
  done

  for(( j=1; j<=${#files[@]}; j++ )); do
    echo -e "${j}) ${txtYellow}${files[$j]}${txtOff}"
  done

  __print_prompt "Your choice:"
  read choice

  if [ -f $CREDENTIALS_CACHE_DIR/${files[$choice]} ]; then
    # Have to assign to global variable since we can't use read command when reading 
    # return value from a function.
    CHOSEN_CACHE_FILE="$CREDENTIALS_CACHE_DIR/${files[$choice]}"
  fi
}

__remove_credentials()
{
  __list_cached_credentials_files "Remove credentials"
  [ ! -f "$CHOSEN_CACHE_FILE" ] && __print_error "Invalid option. Aborted!" && exit 1

  rm "$CHOSEN_CACHE_FILE"
  [ $? -eq 0 ] && __print_info "File removed" || __print_error "Failed to remove file"
}

__update_credentials()
{
  __list_cached_credentials_files "Update credentials"
  [ ! -f "$CHOSEN_CACHE_FILE" ] && __print_error "Invalid option. Aborted!" && exit 1

  local key="" email=""

  __print_prompt_email && read email && [ -z "$email" ] && email=$DEFAULT_EMAIL_ADDRESS

  while [ -z "$key" ]; do
    __print_prompt "Private key:" && read key
  done

  echo "#!/bin/bash" > $CHOSEN_CACHE_FILE
  echo "EMAIL_ADDRESS=$email" >> $CHOSEN_CACHE_FILE
  echo "PRIVATE_KEY=$key" >> $CHOSEN_CACHE_FILE
  __print_info "Credentials updated!"
}

__get_credentials_file()
{
  echo "$CREDENTIALS_CACHE_DIR/$1"
}

__prepare_credentials_store()
{
  [ ! -d "$CREDENTIALS_CACHE_DIR" ] && mkdir $CREDENTIALS_CACHE_DIR
}

__reset_variables()
{
  SITE_NAME=""
  EMAIL_ADDRESS=""
  PRIVATE_KEY=""
  COMMAND=""
}

__add_credentials()
{
  local site_name="" email="" key=""

  __print_prompt "Site name [default]:" && read site_name && [ -z "$site_name" ] && site_name=$DEFAULT_SITE_NAME
  __print_prompt_email && read email && [ -z "$email" ] && email=$DEFAULT_EMAIL_ADDRESS

  while [ -z "$key" ]; do
    __print_prompt "Private key:" && read key
  done

  __prepare_credentials_store

  local confirm="y" cred_file=$(__get_credentials_file $site_name)

  if [ -f "$cred_file" ] && [ -z "$(cat $cred_file)" ]; then
    confirm=$(__prompt_user_input "WARNING: Credentials for site $(__to_uppercase $site_name) is existing. Do you want to override it? [y/n] ")
  else
    touch $cred_file
  fi

  case "$confirm" in
    y|Y)
      echo "#!/bin/bash" > $cred_file
      echo "EMAIL_ADDRESS=$email" >> $cred_file
      echo "PRIVATE_KEY=$key" >> $cred_file
      __print_info "Credentials added!"
      ;;
    *)
      echo "Aborted!"
      ;;
  esac
}

__get_environment()
{
  local environments=(dev stg prod) choice
  select choice in "${environments[@]}"; do
    case $REPLY in
      1|2|3)
        break
        ;;
      *)
        ;;
    esac
  done

  [ "$choice" == "stg" ] && choice="test"
  echo $choice
}

__parse_commands_file()
{
  [ ! -f "$COMMAND_FILE_PATH" ] && __print_error "Command file not found" && exit 1
  local line category old_ifs=$IFS verbose=""
  [ "$1" == "verbose" ] && verbose="verbose"

  while read line; do
    [ -z "$line" ] && continue

    category=$(__is_category_line $line)
    if [ ! -z "$category" ]; then
      category=${category/#[/}
      category=${category/%]/}
      [ ! -z "$verbose" ] && echo -e "\n$(__to_uppercase $category)" && echo '-----------------------------------------------------'
    else
      IFS=$';'
      __parse_command_line $line
      [ ! -z "$verbose" ] && echo -e "$COMMAND_INDEX) ${txtYellow}${COMMAND_NAMES[$COMMAND_INDEX]}:${txtOff} ${COMMAND_DESCS[$COMMAND_INDEX]}"
      let "COMMAND_INDEX+=1"
    fi
  done < $COMMAND_FILE_PATH

  IFS=$old_ifs
}

__parse_command_line()
{
  local cmd_name=$1 cmd_method=$2 cmd_desc=$3 cmd_path=$4
  COMMAND_NAMES[$COMMAND_INDEX]="$cmd_name"
  COMMAND_METHODS[$COMMAND_INDEX]="$cmd_method"
  COMMAND_DESCS[$COMMAND_INDEX]="$cmd_desc"
  COMMAND_PATHS[$COMMAND_INDEX]="$cmd_path"
}

__get_command_index_from_name()
{
  local cmd_index=0
  for (( i=1; i<=${#COMMAND_NAMES[@]}; i++ )); do
    [ "$1" == "${COMMAND_NAMES[$i]}" ] && cmd_index=$i && break
  done
  echo $cmd_index
}

__is_category_line()
{
  echo $1 | grep "\[*\]"
}

__beautify_json_output()
{
  which python>/dev/null && echo "$1" | python -m json.tool
}

__to_uppercase()
{
  echo $1|tr '[:lower:]' '[:upper:]'
}

__to_lowercase()
{
  echo $1|tr '[:upper:]' '[:lower:]'
}

__is_integer()
{
  echo $1 | grep -E ^[0-9]+$
}

__print_prompt_email()
{
  __print_prompt "Email address [$DEFAULT_EMAIL_ADDRESS]:"
}

__get_sitename()
{
  __print_prompt "Site name:" && read SITE_NAME 
}

__get_email_address()
{
  __print_prompt_email && read EMAIL_ADDRESS && [ -z "$EMAIL_ADDRESS" ] && EMAIL_ADDRESS=$DEFAULT_EMAIL_ADDRESS
}

__get_private_key()
{
  __print_prompt "Private key:" && read PRIVATE_KEY
}

__get_site_realm()
{
  echo "prod:$SITE_NAME"
}

__init_command_path()
{
  PREPARED_COMMAND_PATH=${COMMAND_PATHS[$COMMAND_INDEX]}
}

__get_command()
{

  COMMAND_INDEX=0
  local command_id=""
  __print_prompt "\nEnter the command number or command name:" && read command_id
  [ ! -z "$(__is_integer $command_id)" ] && COMMAND_INDEX=$command_id || COMMAND_INDEX=$(__get_command_index_from_name $command_id)
  [ $COMMAND_INDEX -lt 1 ] || [ $COMMAND_INDEX -gt ${#COMMAND_NAMES[@]} ] && __print_error "Invalid command number or name. Aborted!" && exit 1
  __init_command_path
}

__ensure_command_params()
{
  local params=() index=1
  for param in "$@"; do
    [ -z "$param" ] || [ ! -z "$(echo $param|grep -v ":")" ] && continue

    case "$param" in
      :site)
        __replace_command_pattern $param $(__get_site_realm)
        ;;

      :env|:source|:target)
        __replace_command_pattern $param $(__get_environment)
        ;;

      :task)
        __replace_command_pattern $param $(__prompt_user_input "Task ID: ")
        ;;

      :sshkeyid)
        __replace_command_pattern $param $(__prompt_user_input "SSH key ID: ")
        ;;

      :domain)
        __replace_command_pattern $param $(__prompt_user_input "Domain name: ")
        ;;

      :db)
        __replace_command_pattern $param $(__prompt_user_input "Database name: ")
        ;;

      :backup)
        __replace_command_pattern $param $(__prompt_user_input "Database backup ID: ")
        ;;

      :server)
        __replace_command_pattern $param $(__prompt_user_input "Server name: ")
        ;;
    esac
  done
}

__is_async_command()
{
  local state=$(__parse_json $1 "state")
  [ "$state" == "waiting" -o "$state" == "received" ] && echo $state || echo ""
}


__get_async_task_id()
{
  local task_id=$(__parse_json $1 "id")
  echo $task_id
}

__wait_for_async_task()
{
  local async=$(__is_async_command $1) task_id=""
  [ ! -z "$async" ] && task_id=$(__get_async_task_id $1)

  [ ! -z "$task_id" ] && __print_warning "Waiting for task: $task_id to complete" && __check_async_task_state $task_id
}

__parse_json()
{
    echo $1 | sed -e 's/[{}]/''/g' | awk -F=':' -v RS=',' "\$1~/\"$2\"/ {print}" | sed -e "s/\"$2\"://" | tr -d "\n\t" | sed -e 's/\\"/"/g' | sed -e 's/\\\\/\\/g' | sed -e 's/^[ \t]*//g' | sed -e 's/^"//'  -e 's/"$//'
}

__replace_command_pattern()
{
  IFS=$' '
  PREPARED_COMMAND_PATH=${PREPARED_COMMAND_PATH/$1/$2}
}

__issue_curl_command()
{
  echo "curl -s -u $EMAIL_ADDRESS:$PRIVATE_KEY -X ${1} ${API_ENDPOINT}${2}.json" > /tmp/command.txt
  echo $(curl -s -u $EMAIL_ADDRESS:$PRIVATE_KEY -X ${1} ${API_ENDPOINT}${2}.json)
}

__check_async_task_state()
{
  local cmd_name="task-info"
  local cmd_index=$(__get_command_index_from_name "$cmd_name")
  local cmd_path=${COMMAND_PATHS[$cmd_index]}
  local cmd_method=${COMMAND_METHODS[$cmd_index]}

  cmd_path=${cmd_path/:site/$(__get_site_realm)}
  cmd_path=${cmd_path/:task/$1}
  local state="" cmd_output="" local delay=0.5

  while [ 1 ]; do
    cmd_output=$(__issue_curl_command $cmd_method $cmd_path)
    state=$(__parse_json "$cmd_output" state)
    echo "State: $state"
    [ "$state" == "done" -o "$state" == "error" ] && break
    sleep $delay
  done
}

__execute_command()
{
  echo "${COMMAND_DESCS[$COMMAND_INDEX]}"
  local old_ifs=$IFS
  IFS=$'/'
  __ensure_command_params $PREPARED_COMMAND_PATH
  IFS=$old_ifs

  local cmd_output=$(__issue_curl_command ${COMMAND_METHODS[$COMMAND_INDEX]} $PREPARED_COMMAND_PATH)
  __beautify_json_output "$cmd_output"
  __wait_for_async_task "$cmd_output"
}

__dry_run_credentials_check()
{
  local cmd_name="database-list"
  local cmd_path='/sites/:site/dbs'

  cmd_path=${cmd_path/:site/$(__get_site_realm)}
  local cmd_output=$(__issue_curl_command "GET" "$cmd_path")
  message=$(__parse_json "$cmd_output" message)

  [ "$message" == "Not authorized" ] && EMAIL_ADDRESS="" && PRIVATE_KEY="" && __print_error "Default credentials failed for this site. Please enter new one"
}

__ensure_valid_credentials()
{
  local cred_file=$(__get_credentials_file $SITE_NAME) default_cred_file=$(__get_credentials_file $DEFAULT_SITE_NAME)

  if [ -f "$cred_file" ]; then
    source $cred_file
  else
    source $default_cred_file
  fi

  __dry_run_credentials_check
}

__get_command_params()
{
  local cmd_path=$1
  local cmd_parts=${cmd_path//\// }
  shift

  # Ignore site name & command name which have been read already
  [ $# -eq 1 ] && shift
  [ $# -ge 2 ] && shift && shift

  for breadcrumb in $cmd_parts; do
    [ -z "$breadcrumb" ] || [ ! -z "$(echo $breadcrumb|grep -E -v "^:")" ] && continue
    [ -z "$1" ] && break

    case $breadcrumb in
      :site)
        __replace_command_pattern $breadcrumb $(__get_site_realm)
        ;;

      *)
        __replace_command_pattern $breadcrumb $1 && shift
        ;;
    esac
  done
}

__get_options()
{
  if [ $# -eq 1 ]; then
    case "$1" in
      --help|-help)
        __print_usage
        ;;

      --update|-update)
        __check_update verbose
        ;;

      --list-cred|-list)
        __print_cached_credentials
        ;;

      --version|-version)
        __print_current_version
        ;;

      --add-cred|-add)
        __add_credentials
        ;;

      *) 
        SITE_NAME=$1
        ;;
    esac
    [ -z "$SITE_NAME" ] && exit 0
  fi

  [ $# -ge 2 ] && SITE_NAME=$1 && COMMAND=$2

  [ -z "$SITE_NAME" ] && __get_sitename
  __ensure_valid_credentials

  [ -z "$EMAIL_ADDRESS" ] && __get_email_address
  [ -z "$PRIVATE_KEY" ] && __get_private_key

  if [ -z "$COMMAND" ]; then
    __parse_commands_file verbose && __get_command
  else
    __parse_commands_file && COMMAND_INDEX=$(__get_command_index_from_name "$COMMAND") && __init_command_path
  fi

  __get_command_params $PREPARED_COMMAND_PATH "$@"
}

__check_update
__get_options "$@"
__execute_command
