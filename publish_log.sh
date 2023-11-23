#!/bin/bash

username=""
host=""
site_url=""
auth_token=""

ntfy_url=""
ntfy_topic=""
ntfy_token=""
ntfy_log_path="ntfy.log"
ntfy_title="Back up log finish"
ntfy_tags="warning"

key_pair_location="."
log_directory="."
runOnSudo="0"

run_sudo_command_or_not() {
  local command=$1
  if [ $runOnSudo = "0" ]; then
    eval "sudo $command"
  else
    eval $command
  fi
}

validate_token() {
  local token=$1
  local token_pattern="^[0-9a-fA-F]{32}$"

  if [[ ! "$token" =~ $token_pattern ]]; then
    echo "Invalid token format: $token"
    exit 1
  fi
}

validate_option() {
  local option_name=$1
  local option_value=$2

  if [ -z "$option_value" ]; then
    echo "Error: The $option_name option is required and must have a non-empty value."
    exit 1
  fi
}

argument_check() {
  local option_name=$1
  local numbers_of_arguments=$2

  if [ ! "$numbers_of_arguments" -ge 2 ]; then
    echo "Error: The $option_name option requires an argument."
    exit 1
  fi
}

is_valid_url() {
  local url="$1"
  local url_pattern="https?://((www\.)?[[:alnum:]-]+(\.[[:alnum:]-]+)+(:[0-9]+)?|(\d{1,3}\.){3}\d{1,3})([/?].*)?$"

  if [[ ! "$url" =~ $url_pattern ]]; then
    echo "Invalid URL: $url"
    exit 1
  fi
}

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -u, --username       USERNAME        Specify the username of the Matomo server (required)
  -h, --host           HOST            Specify the IP address of the Matomo server (required)
  --site-url           SITE_URL        Specify the URL where the Matomo server is hosted (required)
  --auth-token         AUTH_TOKEN      Specify the auth token of the Matomo server for writing logs (required)

  --ntfy-url           NTFY_URL        Specify the URL where the NTFY server is hosted (required)
  --ntfy-topic         NTFY_TOPIC      Specify the topic of the NTFY server where the notification is sent (required)
  --ntfy-token         NTFY_TOKEN      Specify the token of the NTFY server where the notification is sent (default: NULL)
  --ntfy-log-path      NTFY_LOG_PATH   Specify the path of the NTFY logs file (default: $ntfy_log_path)
  --ntfy-title         NTFY_TITLE      Specify the title for NTFY notifications (default: $ntfy_title)
  --ntfy-tags          NTFY_TAGS       Specify comma-separated tags for NTFY notifications (default: $ntfy_tags)

  --key-pair-location  KEY_PAIR        Specify the location of the private key to connect to the Matomo server (default: $key_pair_location)
  --log-directory      LOG_DIRECTORY   Specify the directory for storing logs (default: $log_directory)
  --sudo               SUDO            Specify if the script needs to run the Docker command with sudo (default: false)
  -h, --help           HELP            Display this help message
EOF
  exit 1
}

if [ $# -eq 0 ]; then
  usage
fi

while [ $# -gt 0 ]; do
  case "$1" in
    -u|--username)
      argument_check "-u|--username" "$#"
      username=$2
      shift 2
      ;;
    -h|--host)
      argument_check "-h|--host" "$#"
      host=$2
      shift 2
      ;;
    --site-url)
      argument_check "--site-url" "$#"
      is_valid_url $2
      site_url=$2
      shift 2
      ;;
    --auth-token)
      argument_check "--auth-token" "$#"
      validate_token "$2"
      auth_token=$2
      shift 2
      ;;
    --ntfy-url)
      argument_check "--ntfy-url" "$#"
      is_valid_url $2
      ntfy_url=$2
      shift 2
      ;;
    --ntfy-topic)
      argument_check "--ntfy-topic" "$#"
      ntfy_topic=$2
      shift 2
      ;;
    --ntfy-token)
      argument_check "--ntfy-token" "$#"
      ntfy_token=$2
      shift 2
      ;;
    --ntfy-log-path)
      argument_check "--ntfy-log-path" "$#"
      ntfy_log_path=$2
      shift 2
      ;;
    --ntfy-title)
      argument_check "--ntfy-title" "$#"
      ntfy_title=$2
      shift 2
      ;;
    --ntfy-tags)
      argument_check "--ntfy-tags" "$#"
      ntfy_tags=$2
      shift 2
      ;;
    --key-pair-location)
      argument_check "--key-pair-location" "$#"
      key_pair_location=$2
      shift 2
      ;;
    --log-directory)
      argument_check "--log-directory" "$#"
      log_directory=$2
      shift 2
      ;;
    --sudo)
      runOnSudo="1"
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Error: Invalid option: $1"
      usage
      ;;
  esac
done


# Validate options
validate_option "-u|--username" "$username"
validate_option "-h|--host" "$host"
validate_option "-s|--site-url" "$site_url"
validate_option "-a|--auth-token" "$auth_token"
validate_option "-k|--key-pair" "$key_pair_location"
validate_option "--ntfy-url" "$ntfy_url"
validate_option "--ntfy-topic" "$ntfy_topic"

cd "$log_directory"

log_file_date=$(date -d "yesterday" +"%y%m%d")

recent_log_file="u_ex$log_file_date.log"

python import_logs.py --url=$site_url --token-auth=$auth_token --add-sites-new-hosts --recorders=4 --enable-http-errors --enable-http-redirects --enable-static --enable-bots $recent_log_file | tee "$log_file_date.output.log"

matomo_log_proceed_command="./console core:archive --force-all-websites --url=$site_url"

docker_exec_command=$(run_sudo_command_or_not "docker exec matomo $matomo_log_proceed_command")

ssh -i $key_pair_location -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $username@$host "$docker_exec_command"

./format_log.sh "$log_file_date.output.log"

if [[ $ntfy_topic == /* ]]; then
    ntfy_topic=${ntfy_topic:1}
fi

if [ "${ntfy_url: -1}" = "/" ]; then
  ntfy_url=${ntfy_url::-1}
fi

curl -d "$(cat $ntfy_log_path)"  \
     -H "Title: $ntfy_title" \
     ${ntfy_token:+-H "Authorization: Bearer $ntfy_token"} \
     -H "Tags: $ntfy_tags" \
     $ntfy_url/$ntfy_topic
