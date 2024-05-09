#!/bin/bash

function check_network_health() {
  ping -c 2 -W 1 $1 &> /dev/null
  if [[ $? -ne 0 ]]; then
    prints -r "Check network!\n"
    exit
  fi
}

function check_ip() {
  ping -c 2 -W 1 $1 &> /dev/null
  return $?
}

function check_file_existence() {
  if [[ -f $1 ]]; then
    return 0
  else
    return 1
  fi
}

function check_network_configuration {
  while true
  do
    fix_net_config
    prints -y "\nRestarting network.."
    sudo systemctl restart networking
    if [[ $? -ne 0 ]]; then
      prints -r "\nNetwork configuration error! Press Enter..."; read
      sudo nano /etc/network/interfaces
    else
      break
    fi
  done
}

function check_gateway {
  if [[ ! -z $GATEWAY ]]; then
    input_task "Gateway $(prints -p $GATEWAY) valid?"
    if [[ $? -eq 0 ]]; then
      check_ip $GATEWAY
      if [[ $? -eq 0 ]]; then
        prints -g "Gateway available!"
        return 0
      else
        prints -r "Gateway unavailable!"
        return 1
      fi
    else
      GATEWAY=""
      return 1
    fi
  else
    return 1
  fi
}
