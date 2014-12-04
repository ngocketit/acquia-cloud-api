#!/bin/bash

###############################################################
#               Acquia Cloud Utility	               	      #
#               Author: phi.vanngoc@activearkjwt.com          #
###############################################################
VERSION=0.4
REPOS_URL=http://104.131.99.199/acquia-cloud-util.sh
COMMANDS_REPOS_URL=http://104.131.99.199/acquia-cloud-commands
INSTALL_PATH=/usr/local/bin/acquia-cloud-util
CREDENTIALS_CACHE_DIR=$HOME/.acquia-cloud-util
DEFAULT_EMAIL_ADDRESS=drupal@activeark.com
API_ENDPOINT=https://cloudapi.acquia.com/v1
COMMAND_FILE_PATH=${CREDENTIALS_CACHE_DIR}/.acquia-cloud-commands
DEFAULT_SITE_NAME=default
COMMAND_RESULT_OUTPUT=/tmp/last_cmd

CHOSEN_CACHE_FILE=""

SITE_NAME=""
EMAIL_ADDRESS=""
PRIVATE_KEY=""
COMMAND=""
PREPARED_COMMAND_PATH=""
COMMAND_BODY=""
COMMAND_EXTRA_OPTIONS=""
CHAINED_COMMAND_QUEUE=""
COMMAND_FLAGS=""

COMMAND_NAMES=()
COMMAND_METHODS=()
COMMAND_DESCS=()
COMMAND_PATHS=()
COMMAND_INDEX=1
COMMAND_ARGS_VALUES=()
COMMAND_ARGS_NAMES=()
COMMAND_OPTIONS=()

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
  sudo mv "$1" $INSTALL_PATH && [ -f $INSTALL_PATH ] && sudo chmod a+x $INSTALL_PATH
  local status=$?
  __print_command_status "Self update"
  __download_commands_file

  rm $tmp_file >/dev/null 2>&1
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
    __confirm_update && __do_self_update "$new_version" || [ "$1" == "verbose" ] && exit
  else
    [ "$1" == "verbose" ] && __print_warning "No update available" && exit
  fi
}

__print_usage()
{
  cat <<EOF
Usage: $0 [options] | <site name> <command name> [command arguments]

GENERAL USAGE

-h | --help                   Print out usage

-h | --help [command name]    Print out usage for given command. 
                              For example: $0 --help database-copy

-u | --update                 Check for available update and update the script

-v | --version                Print the current version number

-l | --list                   List the cached credentials

-a | --add                    Add a new credentials

-c | --commands               List all supported commands


COMMAND USAGE
                              You can run the script for a specific command by 
                              passing the command name along with site name as arguments. 
                              The general format is:

                              $0 <site> <command name> [command arguments]

DESCRIPTION:

- site:                       Unique name of the site as on Acquia Cloud. For example, newnokia, nixucom etc

- command name:               Name of the command to be executed. For example, database-copy, task-info etc

- command arguments:          List of required arguments to execute the command. To print out all required arguments
                              use -h or --help with command name. For example, $0 --help database-copy.
                              Any missing arguments will be prompted to enter so you don't need to provide the full
                              list or arguments. 
                              
                              For example: $0 newnokia database-copy dev
                              The source and target environments will be asked to be entered.

EXAMPLES:

- $0 --add <site> <email.address> <key>
                              Add the credentials for site <site>

- $0 --add default drupal@activeark.com <key>
                              Add the credentials for default account

- $0 newnokia                 
                              Only site name is provided, you'll be presenting with a list of commands that you can
                              select along with prompts for required arguments.

- $0 newnokia task-info       
                              Get information about a task. Task ID will be prompted for enter.                                

- $0 newnokia database-copy newnokia prod dev
                              Copy newnokia database from PRODUCTION to DEVELOPMENT

EOF
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

__add_credentials()
{
  shift

  local index=1
  while [ 1 ]; do
    [ -z "$1" ] && break
    [ $index -eq 1 ] && SITE_NAME=$1
    [ $index -eq 2 ] && EMAIL_ADDRESS=$1
    [ $index -eq 3 ] && PRIVATE_KEY=$1

    shift
    let "index+=1"
  done

  [ -z "$SITE_NAME" ] && __print_prompt "Site name [default]:" && read SITE_NAME && [ -z "$SITE_NAME" ] && SITE_NAME=$DEFAULT_SITE_NAME
  [ -z "$EMAIL_ADDRESS" ] && __print_prompt_email && read EMAIL_ADDRESS && [ -z "$EMAIL_ADDRESS" ] && EMAIL_ADDRESS=$DEFAULT_EMAIL_ADDRESS

  while [ -z "$PRIVATE_KEY" ]; do
    __print_prompt "Private key:" && read PRIVATE_KEY
  done

  local confirm="y" cred_file=$(__get_credentials_file $SITE_NAME)

  if [ -f "$cred_file" ] && [ -z "$(cat $cred_file)" ]; then
    confirm=$(__prompt_user_input "WARNING: Credentials for site $(__to_uppercase $SITE_NAME) is existing. Do you want to override it? [y/n] ")
  fi

  case "$confirm" in
    y|Y)
      __save_credentials && __print_info "Credentials added!" && exit 0
      ;;
    *)
      echo "Aborted!" && exit 1
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

__download_commands_file()
{
  __prepare_credentials_store
  curl -o $COMMAND_FILE_PATH $COMMANDS_REPOS_URL 2>/dev/null
}

__parse_commands_file()
{
  [ ! -f "$COMMAND_FILE_PATH" ] && __download_commands_file
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
  [ $# -eq 5 ] && [ ! -z "$5" ] && COMMAND_OPTIONS[$COMMAND_INDEX]=$5
}

__get_command_option()
{
  local cmd_options=${COMMAND_OPTIONS[$COMMAND_INDEX]}
  cmd_options=${cmd_options//|/ }
  local option=""

  for opt in $cmd_options; do
    [ "$1" == "$opt" ] && option=$opt && break
  done

  echo $option
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

__ucase_first()
{
  local input="$1"
  echo ${input^}
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
  local path=$1
  path=${path//\// }
  path=${path//=/ }
  local params=() index=1
  for param in $path; do
    [ -z "$param" ] || [ ! -z "$(echo $param|grep -v ":")" ] && continue

    case "$param" in
      :site)
        __replace_command_pattern $param $(__get_site_realm)
        ;;

      :env)
        __print_warning "Environment:" && __replace_command_pattern $param $(__get_environment)
        ;;

      :source)
        __print_warning "Source environment:" && __replace_command_pattern $param $(__get_environment)
        ;;

      :target)
        __print_warning "Target environment:" && __replace_command_pattern $param $(__get_environment)
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

      :nickname)
        __replace_command_pattern $param $(__prompt_user_input "SSH key nick name: ")
        ;;

      :branch)
        __replace_command_pattern $param $(__prompt_user_input "GIT or SVN tag/branch name: ")
        ;;

      :action)
        __replace_command_pattern $param $(__prompt_user_input "Enable or disable live dev [enable,disable]: ")
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

  [ ! -z "$task_id" ] && __print_warning "Waiting for task $task_id to complete" && __check_async_task_state $task_id
}

__parse_json()
{
    echo $1 | sed -e 's/[{}]/''/g' | awk -F=':' -v RS=',' "\$1~/\"$2\"/ {print}" | sed -e "s/\"$2\"://" | tr -d "\n\t" | sed -e 's/\\"/"/g' | sed -e 's/\\\\/\\/g' | sed -e 's/^[ \t]*//g' | sed -e 's/^"//'  -e 's/"$//'
}

__replace_command_pattern()
{
  IFS=$' '
  PREPARED_COMMAND_PATH=${PREPARED_COMMAND_PATH/$1/$2}
  local length=${#COMMAND_ARGS_VALUES[@]}
  let "length+=1"
  COMMAND_ARGS_NAMES[$length]=$1
  COMMAND_ARGS_VALUES[$length]=$2
}

__issue_curl_command()
{
  local cmd_method=$1 cmd_path=$2 cmd_body="$3"
  # Make sure that the .json is appended to the correct location in the path
  if [ ! -z "$(echo $cmd_path | grep ?)" ]; then
    cmd_path=${cmd_path//\?/\.json\?}
  else
    cmd_path=$(echo "${cmd_path}.json")
  fi

  if [ -z "$cmd_body" ]; then
    echo $(curl ${COMMAND_FLAGS} -u $EMAIL_ADDRESS:$PRIVATE_KEY -X ${cmd_method} ${API_ENDPOINT}${cmd_path}${COMMAND_EXTRA_OPTIONS})
    echo "curl ${COMMAND_FLAGS} -u $EMAIL_ADDRESS:$PRIVATE_KEY -X ${cmd_method} ${API_ENDPOINT}${cmd_path}${COMMAND_EXTRA_OPTIONS}" >/tmp/command.txt
  else
    echo $(curl ${COMMAND_FLAGS} -u $EMAIL_ADDRESS:$PRIVATE_KEY -X ${cmd_method} --data "${cmd_body}" ${API_ENDPOINT}${cmd_path}${COMMAND_EXTRA_OPTIONS})
    echo "curl ${COMMAND_FLAGS} -u $EMAIL_ADDRESS:$PRIVATE_KEY -X ${cmd_method} --data "${cmd_body}" ${API_ENDPOINT}${cmd_path}${COMMAND_EXTRA_OPTIONS}" >/tmp/command.txt
  fi
}

__check_async_task_state()
{
  local cmd_name="task-info"
  local cmd_index=$(__get_command_index_from_name "$cmd_name")
  local cmd_path=${COMMAND_PATHS[$cmd_index]}
  local cmd_method=${COMMAND_METHODS[$cmd_index]}

  cmd_path=${cmd_path/:site/$(__get_site_realm)}
  cmd_path=${cmd_path/:task/$1}
  local state="" cmd_output="" local delay=0.5 last_state="" total_time=0

  while [ 1 ]; do
    cmd_output=$(__issue_curl_command $cmd_method $cmd_path)
    state=$(__parse_json "$cmd_output" state)

    if [ "$last_state" != "$state" ]; then
      [ -z "$last_state" ] && printf "State: $state" || printf "..${state}"
    else
      printf "."
    fi
    last_state=$state

    [ "$state" == "done" -o "$state" == "error" ] && echo " (time: ${total_time} s)" && break
    sleep $delay && total_time=$(echo $total_time + $delay | bc)
  done
}

__is_command_failed()
{
  local message=$(__parse_json "$1" message)
  [ ! -z "$message" ] && echo "$message" || echo ""
}

__is_unauthorized()
{
  local message=$(__parse_json "$1" message)
  [ ! -z "$message" ] && [ "$message" == "Not authorized" ] && echo "$message" || echo ""
}

__retry_credentials()
{
  EMAIL_ADDRESS="" 
  PRIVATE_KEY="" 
  __print_warning "Credentials failed. Please try a new one"
  __get_email_address 
  __get_private_key
}

__save_credentials()
{
  __prepare_credentials_store

  local cred_file=$(__get_credentials_file "$SITE_NAME")
  touch $cred_file
  echo "#!/bin/bash" > $cred_file
  echo "EMAIL_ADDRESS=$EMAIL_ADDRESS" >> $cred_file
  echo "PRIVATE_KEY=$PRIVATE_KEY" >> $cred_file
}

__print_command_confirmation()
{
  local cmd_name=${COMMAND_NAMES[$COMMAND_INDEX]} cmd_desc=$(__to_lowercase "${COMMAND_DESCS[$COMMAND_INDEX]}")
  __print_warning "WARNING: You are about to execute the command ${cmd_name} which will $cmd_desc with following arguments:"
  for (( i=1; i<=${#COMMAND_ARGS_VALUES[@]}; i++ )); do
    echo "* $(__ucase_first ${COMMAND_ARGS_NAMES[$i]//:/}): ${COMMAND_ARGS_VALUES[$i]}"
  done
  __print_prompt "Do you want to continue? [y/n]"
}

__set_chained_command_queue()
{
  CHAINED_COMMAND_QUEUE="chained"
}

__clear_chained_command_queue()
{
  CHAINED_COMMAND_QUEUE=""
}

__preparare_hooked_command()
{
  local cmd_name=$1
  COMMAND_INDEX=$(__get_command_index_from_name $cmd_name)
  shift

  __init_command_path
  __get_command_params $PREPARED_COMMAND_PATH $SITE_NAME $cmd_name $@

  # Mark that further command to be executed
  __set_chained_command_queue
}

__pre_database_copy()
{
  local database_name=${COMMAND_ARGS_VALUES[2]}
  local target_env=${COMMAND_ARGS_VALUES[4]}
  __preparare_hooked_command database-backup $target_env $database_name
}

__post_database_copy()
{
  local target_env=${COMMAND_ARGS_VALUES[4]}

  # Enable shield on dev/test environments
  if [ "$target_env" == "dev" -o "$target_env" == "test" ]; then
    __print_warning "Enable shield module on $(__to_uppercase $target_env)"
    drush @${SITE_NAME}.${target_env} en shield --yes
  fi

  # No command to follow this so clear the queue
  __clear_chained_command_queue
}

__execute_command_hook()
{
  local hook=$1
  local cmd_name=${COMMAND_NAMES[$COMMAND_INDEX]}
  local cmd_name_processed=${cmd_name//\-/_}
  local func_name="__${hook}_${cmd_name_processed}"
  type $func_name >/dev/null 2>&1

  if [ $? -eq 0 ]; then
    # Save context of old command
    local old_cmd_index=$COMMAND_INDEX
    local old_cmd_path=$PREPARED_COMMAND_PATH

    $func_name && [ ! -z "$CHAINED_COMMAND_QUEUE" ] && __execute_command

    # Restore old commands 
    COMMAND_INDEX=$old_cmd_index
    PREPARED_COMMAND_PATH=$old_cmd_path
  fi
}

__get_command_body_sshkey_add()
{
  local sshkey="" shell_access=true code_access=true blacklist="" envs=""

  while [ -z "$sshkey" ]; do
    sshkey=$(__prompt_user_input "SSH key file or hash: ")
    [ -f "$sshkey" ] && sshkey=$(cat "$sshkey")
  done

  shell_access=$(__prompt_user_input "Allow shell access for this key [yes]? [y/n] ")
  case "$shell_access" in
    n|N)
      shell_access="false"
      ;;

    *)
      shell_access="true"
      ;;
  esac

  code_access=$(__prompt_user_input "Allow access to code (GIT, SVN) for this key [yes]? [y/n] ")
  case "$code_access" in
    n|N)
      code_access="false"
      ;;

    *)
      code_access="true"
      ;;
  esac

  envs=$(__prompt_user_input "Disallow access to environments (type dev,test,prod separated by commas) [allow all]? ")

  if [ ! -z "$envs" ]; then
    envs=${envs//,/ }

    for env in $envs; do
      blacklist=$(echo "${blacklist}\"$env\",")
    done
    blacklist=${blacklist/%,/}
    blacklist=$(echo "[${blacklist}]")
    blacklist=",\"blacklist\": ${blacklist}"
  fi

  COMMAND_BODY="{\"ssh_pub_key\":\"${sshkey}\",\"shell_access\":${shell_access},\"vcs_access\":${code_access}${blacklist}}"
}

__get_command_body_database_add()
{
  local db_name=$(__prompt_user_input "Name of new database: ")

  COMMAND_BODY="{\"db\":\"${db_name}\"}"
}

__get_command_body()
{
  COMMAND_BODY=""
  local cmd_name=${COMMAND_NAMES[$COMMAND_INDEX]}
  local cmd_name_processed=${cmd_name//\-/_}
  local func_name="__get_command_body_${cmd_name_processed}"

  type $func_name >/dev/null 2>&1
  [ $? -eq 0 ] && $func_name
}

__get_command_extra_options()
{
  COMMAND_EXTRA_OPTIONS=""
  local cmd_name=${COMMAND_NAMES[$COMMAND_INDEX]}
  local cmd_name_processed=${cmd_name//\-/_}
  local func_name="__get_command_extra_options_${cmd_name_processed}"

  type $func_name >/dev/null 2>&1
  [ $? -eq 0 ] && $func_name
}

__get_command_extra_options_database_backup_download()
{
  local saved_file_path=$(__prompt_user_input "Save database backup to: ")
  COMMAND_EXTRA_OPTIONS=" -o $saved_file_path"
}

__pre_varnish_purge()
{
  __preparare_hooked_command server-list prod
}

__purge_varnish_elb()
{
  local server=$1 url=$2
  local domain=$(echo $url | cut -d'/' -f3)
  local path=$(echo $url| awk -F $domain/ '{print $2}')

  curl -s -D - -X PURGE -H "X-Acquia-Purge: $SITE_NAME" --compress -H "Host: $domain" http://${server}.prod.hosting.acquia.com/$path -o /dev/null
}

__command_varnish_purge()
{
  local last_cmd_output=$(cat $COMMAND_RESULT_OUTPUT)
  local balancers=$(__beautify_json_output "$last_cmd_output" | grep -E "\"name\": \"bal-[0-9]+\"" | awk -F": " '{print $2}' | sed 's/[", ]//g' | tr "\\n" " ")

  [ -z "$balancers" ] && __print_error "No load balancers found" && exit 1

  local paths=() path="" index=1

  # If URLs are passed as command arguments
  if [ $# -ge 3 ]; then
    shift && shift

    # If the argument is actually a file path
    if [ $# -eq 1 -a -f $1 ]; then
      while read path; do
        paths[$index]=$path
        let "index+=1"
      done < $1
    else
      while [ ! -z "$1" ]; do
        paths[$index]=$1
        let "index+=1"
        shift
      done
    fi
  else
    __print_warning "Enter the URLs you want to purge. Press enter twice to finish inputting"

    while read path; do
      [ -z "$path" ] && break
      paths[$index]=$path
      let "index+=1"
    done
  fi

  [ ${#paths[@]} -eq 0 ] && __print_error "No path to purge" && exit 1

  for server in $balancers; do
    __print_info "# # # Server: $server # # #"

    for (( i=1; i <= ${#paths[@]}; i++ )); do
      __print_warning "# # # Path: ${paths[$i]} # # #"
      __purge_varnish_elb $server ${paths[$i]}
    done
  done
}

__is_non_api_command()
{
  echo $(__get_command_option "non-api")
}

__execute_non_api_command()
{
  local cmd_name=${COMMAND_NAMES[$COMMAND_INDEX]}
  local cmd_name_processed=${cmd_name//\-/_}
  local func_name="__command_${cmd_name_processed}"
  type $func_name >/dev/null 2>&1

  [ $? -eq 0 ] && $func_name "$@"
}

__execute_command()
{
  __ensure_command_params $PREPARED_COMMAND_PATH

  __get_command_body
  __get_command_extra_options
  __get_command_flags

  local num_attempts=0 cmd_output="" cmd_state="" cmd_confirm="y"

  [ ! -z "$(__get_command_option confirm)" ] && __print_command_confirmation && read cmd_confirm

  case "$cmd_confirm" in
    n|N)
      __print_error "Aborted!" && exit 1
      ;;
  esac

  __execute_command_hook pre

  echo "${COMMAND_DESCS[$COMMAND_INDEX]}"

  if [ ! -z "$(__is_non_api_command)" ]; then
    __execute_non_api_command "$@"
  else
    while [ 1 ]; do
      let "num_attempts+=1"
      cmd_output=$(__issue_curl_command ${COMMAND_METHODS[$COMMAND_INDEX]} $PREPARED_COMMAND_PATH "$COMMAND_BODY")
      __beautify_json_output "$cmd_output" && cmd_state=$(__is_unauthorized "$cmd_output")
      [ "$num_attempts" -ge 3 ] && __print_error "You are out of luck. Please make sure you have correct credentials and access rights!" && break
      [ ! -z "$cmd_state" ] && __retry_credentials || break
    done

    echo "$cmd_output" > $COMMAND_RESULT_OUTPUT

    [ -z "$cmd_state" ] && __save_credentials && __wait_for_async_task "$cmd_output"
  fi

  __execute_command_hook post
}

__get_command_flags_database_backup_download()
{
  COMMAND_FLAGS="-L"
}

__get_command_flags()
{
  COMMAND_FLAGS="-s"
  local cmd_name=${COMMAND_NAMES[$COMMAND_INDEX]}
  local cmd_name_processed=${cmd_name//\-/_}
  local func_name="__get_command_flags_${cmd_name_processed}"

  type $func_name >/dev/null 2>&1
  [ $? -eq 0 ] && $func_name
}

__ensure_valid_credentials()
{
  local cred_file=$(__get_credentials_file $SITE_NAME) default_cred_file=$(__get_credentials_file $DEFAULT_SITE_NAME)

  if [ -f "$cred_file" ]; then
    source $cred_file
  else
    [ -f "$default_cred_file" ] && source $default_cred_file
  fi
}

__get_command_params()
{
  local cmd_path=${1//=/ }
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

__print_command_help()
{
  __parse_commands_file

  local script_name=$1 cmd=$2
  local cmd_index=$(__get_command_index_from_name $cmd)
  [ $cmd_index -lt 1 -o $cmd_index -gt ${#COMMAND_NAMES[@]} ] && __print_error "Invalid command name!" && exit 1

  echo -e "${txtYellow}${COMMAND_NAMES[$cmd_index]}:${txtOff} ${COMMAND_DESCS[$cmd_index]}"
  local cmd_path=${COMMAND_PATHS[$cmd_index]//\// }
  printf "Usage: $script_name <site> $cmd "

  case "$cmd" in
    varnish-purge)
      printf "[<URLs> | <file path containing URLs to be purged>]"
      echo
      cat <<EOF

Examples:

    - $script_name site_name varnish-purge
    - $script_name site_name varnish-purge http://site.name.com/path1 http://site.name.com/path2
    - $script_name site_name varnish-purge /tmp/paths.txt
EOF
      ;;

    *)
      for breadcrumb in $cmd_path; do
        [ -z "$breadcrumb" ] || [ ! -z "$(echo $breadcrumb|grep -E -v "^:")" ] || [ "$breadcrumb" == ":site" ] && continue
        printf "<${breadcrumb//:/}> "
      done
      ;;
  esac
  echo
}


__print_supported_commands()
{
  echo "COMMAND LIST"
  __parse_commands_file verbose
}

__get_options()
{
  case "$1" in
    --help|-h)
      [ -z "$2" ] && __print_usage || __print_command_help $0 $2
      ;;

    --update|-u)
      __check_update verbose
      ;;

    --list|-l)
      __print_cached_credentials
      ;;

    --version|-v)
      __print_current_version
      ;;

    --add|-a)
      __add_credentials "$@"
      ;;

    --commands|-c)
      __print_supported_commands
      ;;

    -*)
      __print_error "Invalid option!" && exit 1
      ;;

    *) 
      SITE_NAME=$1
      ;;
  esac

  [ $# -ge 1 ] && [ -z "$SITE_NAME" ] && exit 1

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

  [ $COMMAND_INDEX -lt 1 -o $COMMAND_INDEX -gt ${#COMMAND_NAMES[@]} ] && __print_error "Invalid command!" && exit 1

  __get_command_params $PREPARED_COMMAND_PATH "$@"
}

[ "$1" != "--update" -a "$1" != "-u" ] && __check_update
__get_options "$@"
__execute_command "$@"
