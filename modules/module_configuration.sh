#!/bin/bash

function get_network {
  if [[ $(ip r | wc -l) -eq 2 ]]; then
    read -ra INFO <<< "$(ip r | tail -1)"
  else
    while true
    do
      echo; ip a | egrep "state UP|scope global"; echo
      input_data "\n$(prints -c 'Choose an interface number'): "; local data; read data
      ip a | awk '{print $1}' | grep "^$data:" &> /dev/null
      if [[ $? -ne 0 ]]; then
        prints -r "Interface not found!"
      else
        break
      fi
    done
    ETH_NAME="$(ip a | grep "^$data:" | awk '{print $2}' | sed 's/://')"
    read -ra INFO <<< "$(ip r | grep / | grep $ETH_NAME)"
  fi

  ETH_NAME=${INFO[2]}
  NETWORK=${INFO[0]}
  IP=${INFO[8]}

  OCTETS=(`echo $IP | tr '.' ' '`)
  REVERSE_IP="${OCTETS[2]}.${OCTETS[1]}.${OCTETS[0]}"

  get_netmask
}

function network_interfaces {
  local CONF="/etc/network/interfaces"
  check_file_existence $CONF
  if [[ $? -eq 0 ]]; then
    local LINE=$(find_line_number $CONF "iface $ETH_NAME inet dhcp")
    if [[ ! -z $LINE ]]; then
      cat $CONF | grep "auto $ETH_NAME" &> /dev/null
      if [[ $? -ne 0 ]]; then
        sudo sed -i "${LINE}i auto $ETH_NAME" $CONF
        LINE=$(find_line_number $CONF "iface $ETH_NAME inet dhcp")
      fi
      sudo sed -i "
      s|iface $ETH_NAME inet dhcp|iface $ETH_NAME inet static|
      ${LINE}a \\\taddress $IP/$NETMASK
      ${LINE}a \\\tgateway $GATEWAY
      " $CONF
    fi
  fi
  check_network_configuration
}

function find_gateway {
  while true
  do
    prints "\n1 -> Find and select a gateway"
    prints "2 -> Set gateway manually\n"
    input_data "$(prints -c 'Choose action'): "; local data; read data
    case $data in
      1)
        set_gateway_from_list
        check_gateway
        if [[ $? -eq 0 ]]; then
          break
        fi
        ;;
      2)
        set_gateway_manually
        check_gateway
        if [[ $? -eq 0 ]]; then
          break
        fi
        ;;
      *)
        prints -r "Command number is invalid!"
        ;;
    esac
  done
}

function set_gateway_from_list {
  local STATUS="REACHABLE|STALE"
  if [[ $(ip n show dev $ETH_NAME | egrep $STATUS | wc -l) -ne 0 ]]; then
    echo; ip n show dev $ETH_NAME | egrep $STATUS | nl -s ': '; echo
    input_data "$(prints -c 'Choose gateway number'): "; local data; read data
    local GW=$(ip n show dev $ETH_NAME | egrep $STATUS | nl -s ': ' | egrep "^\s+$data:\s")
    if [[ $? -ne 0 ]]; then
      prints -r "Gateway not found!"
    else
      GATEWAY=$(echo $GW | awk {'print $2'})
    fi
  else
    GATEWAY=""
    prints -r "Gateways not detect!"
  fi
}

function set_gateway_manually {
  input_data "$(prints -c 'Input gateway'): "; local data; read data
  GATEWAY=$data
}

function fix_net_config {
  local path_net_config="/run/network/ifstate.$ETH_NAME"
  sudo sed -i "d" $path_net_config
  sudo bash -c "echo $ETH_NAME > $path_net_config"
}

function get_netmask {
  NETMASK=(`echo $NETWORK | tr '/' ' '`)
  NETMASK=${NETMASK[1]}
}

function find_line_number() {
  local NUMBER=(`cat "$1" | grep -n "$2" | head -1 | tr ':' ' '`)
  prints ${NUMBER[0]}
}
