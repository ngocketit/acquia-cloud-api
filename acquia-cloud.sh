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
COMMAND_FILE_PATH=./acquia-commands.sh

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
  while [ -z "$site_name" ]; do
    __print_prompt "Site name:" && read site_name
  done

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

__print_cloud_operations()
{
  local task_ops=("task-list" "task-info")
  local domain_ops=("domain-add" "domain-info" "domain-delete" "domain-list" "domain-move" "domain-purge")
  local database_ops=("database-add" "database-copy" "database-delete" "database-info" "database-list")
}

__parse_commands_file()
{
  [ ! -f "$COMMAND_FILE_PATH" ] && __print_error "Command file not found" && exit 1
  local line category old_ifs=$IFS

  while read line; do
    [ -z "$line" ] && continue

    category=$(__is_category_line $line)
    if [ ! -z "$category" ]; then
      category=${category/#[/}
      category=${category/%]/}
      echo -e "\n$(__to_uppercase $category)"
    else
      IFS=$';'
      __parse_command_line $line
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
  echo -e "$COMMAND_INDEX) ${txtYellow}$cmd_name:${txtOff} $cmd_desc"
}

__get_command_index_from_name()
{
  local cmd_index
  for (( i=1; i<=${#COMMANDS_NAMES[@]}; i++ )); do
    cmd_index=$i
    [ "$1" == "$COMMANDS_NAMES[$i]" ] && break
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

__get_command()
{
  __parse_commands_file

  COMMAND_INDEX=""
  __print_prompt "Enter the command number:"
  read COMMAND_INDEX
  PREPARED_COMMAND_PATH=${COMMAND_PATHS[$COMMAND_INDEX]}
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
    esac
  done
}

__replace_command_pattern()
{
  IFS=$' '
  PREPARED_COMMAND_PATH=${PREPARED_COMMAND_PATH/$1/$2}
}

__execute_command()
{
  echo "${COMMAND_DESCS[$COMMAND_INDEX]}"
  local old_ifs=$IFS
  IFS=$'/'
  __ensure_command_params ${COMMAND_PATHS[$COMMAND_INDEX]}
  IFS=$old_ifs

  local cmd_output=$(curl -s -u $EMAIL_ADDRESS:$PRIVATE_KEY -X ${COMMAND_METHODS[$COMMAND_INDEX]} ${API_ENDPOINT}${PREPARED_COMMAND_PATH}.json)
  __beautify_json_output "$cmd_output"
}

__get_options()
{
  [ $# -eq 2 ] && SITE_NAME=$1 && COMMAND=$2

  [ -z "$SITE_NAME" ] && __get_sitename
  local cred_file=$(__get_credentials_file $SITE_NAME)

  [ -f "$cred_file" ] && source $cred_file
  [ -z "$EMAIL_ADDRESS" ] && __get_email_address
  [ -z "$PRIVATE_KEY" ] && __get_private_key

  [ ! -z "$COMMAND" ] && COMMAND_INDEX=$(__get_command_index_from_name $COMMAND)
  [ -z "$COMMAND" ] && __get_command
}


if [ $# -eq 1 ]; then
  case "$1" in
    --help|-help)
      __print_usage
      exit 0
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
      ;;
  esac
else
  __check_update
  __get_options "$@"
  __execute_command
fi
