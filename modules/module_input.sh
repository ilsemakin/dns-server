#!/bin/bash

DOMAIN=""
DNS=""

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PURPLE="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"

function prints() {
  case $1 in
    -r)
      echo -e "${RED}$2${RESET}"
      ;;
    -g)
      echo -e "${GREEN}$2${RESET}"
      ;;
    -y)
      echo -e "${YELLOW}$2${RESET}"
      ;;
    -p)
      echo -e "${PURPLE}$2${RESET}"
      ;;
    -c)
      echo -e "${CYAN}$2${RESET}"
      ;;
    *)
      echo -e "$1"
      ;;
  esac
}

function input_data() {
  case $1 in
    -r)
      echo -n -e "${RED}$2${RESET}"
      ;;
    -g)
      echo -n -e "${GREEN}$2${RESET}"
      ;;
    -y)
      echo -n -e "${YELLOW}$2${RESET}"
      ;;
    -p)
      echo -n -e "${PURPLE}$2${RESET}"
      ;;
    -c)
      echo -n -e "${CYAN}$2${RESET}"
      ;;
    *)
      echo -n -e "$1"
      ;;
  esac
}

function input_task() {
  input_data "$1 [Y/n] > "; local data; read data; data=${data,,}
  if [[ $data == "y" ]] || [[ $data == "yes" ]]; then
    return 0
  else
    return 1
  fi
}

function input_task_yes() { prints "$1 [Y/n] > Yes"; return 0; }
function input_task_no() { prints "$1 [Y/n] > No"; return 1; }

function input_domain {
  if [[ -z $DOMAIN ]]; then
    echo
    while true
    do
      input_data "$(prints -c 'Input domain name'): "; local data; read data; data=${data,,}
      input_task "Domain name $(prints -p $data) is valid?"
      if [[ $? -eq 0 ]]; then
        DOMAIN="$data"
        break
      fi
      echo
    done
  fi
  FQDN="$HOSTNAME.$DOMAIN"
}

function input_dns {
  if [[ -z $DNS ]]; then
    echo
    while true
    do
      input_data "$(prints -c 'Input DNS server IP address'): "; local data; read data; data=${data,,}
      input_task "DNS Server $(prints -p $data) is valid?"
      if [[ $? -eq 0 ]]; then
        check_ip $data
        if [[ $? -eq 0 ]]; then
          DNS="$data"
          prints -g "DNS server available!\n"
          break
        else
          prints -r "DNS server unavailable!\n"
          continue
        fi
      fi
      echo
    done
  fi
}
