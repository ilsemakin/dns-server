#!/bin/bash

HOSTNAME="dns"

# HOME_DIR=$(dirname $0)
HOME_DIR=$(dirname -- "$(readlink -f -- "$0")")
# HOME_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

source $HOME_DIR/module_mgmt.sh $HOME_DIR

function main() {
  echo
  check_network_health 77.88.8.8
  get_network
  echo

  fix_net_config

  input_task "Upgrade packages?"
  if [[ $? -eq 0 ]]; then
    sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y
    prints -g "\nDone!\n"
  fi

  input_task "Set a static IP address?"
  if [[ $? -eq 0 ]]; then
    find_gateway
    network_interfaces
    check_network_health 77.88.8.8
    prints -g "Done!\n"
  fi

  input_task "Configure time?"
  if [[ $? -eq 0 ]]; then
    sudo apt update &> /dev/null
    sudo apt install chrony -y

    sudo timedatectl set-timezone Europe/Moscow
    sudo systemctl enable chrony
    sudo systemctl restart chrony

    prints -g "\nDone!\n"
  fi

  input_domain

  input_task "Configure resolvconf?"
  if [[ $? -eq 0 ]]; then
    sudo sed -i "
    s|^.*DNS=.*$|DNS=${IP}|
    s|^.*Domains=.*$|Domains=${DOMAIN}|
    " /etc/systemd/resolved.conf

    sudo systemctl enable systemd-resolved.service
    sudo systemctl start systemd-resolved.service

    sudo systemctl restart systemd-resolved.service
    #sudo systemctl status systemd-resolved.service

    echo

    sudo rm -f /etc/resolv.conf
    sudo ln -svi /run/systemd/resolve/resolv.conf /etc/resolv.conf

    prints -g "\nDone!\n"
  fi

  input_task "Configure hostname?"
  if [[ $? -eq 0 ]]; then
    sudo hostnamectl set-hostname ${HOSTNAME} &> /dev/null
    sudo sed -i "1s|.*$|127.0.0.1\tlocalhost ${HOSTNAME}|" /etc/hosts &> /dev/null

    check_network_configuration
    #echo; cat /etc/hosts | head -2
    prints -g "Done!\n"
  fi

  input "Install and configure bind9?"
  if [[ $? -eq 0 ]]; then
    if [[ -z $GATEWAY ]]; then
      find_gateway
    fi

    check_file_existence "/etc/default/named"
    if [[ $? -ne 0 ]]; then
      sudo apt purge bind9 -y &> /dev/null
      sudo rm -rf /etc/bind /var/cache/bind
    fi

    sudo apt update && sudo apt install bind9 bind9-doc -y
    sudo sed -i "s|bind\"|bind -4\"|" /etc/default/named

    cd /etc/bind/
    sudo mkdir zones &> /dev/null
    sudo cp db.local zones/db.${DOMAIN}
    sudo cp db.local zones/db.${REVERSE_IP}

    sudo sed -i "11s|^include|//include|" named.conf

    sudo sed -i "
      s|dnssec-validation auto|dnssec-validation no|
      s|^\tlisten-on-v6|\t//listen-on-v6|
      13s|//.forwarders|forwarders|
      14s|//.||
      14s|.*$|\t\t${GATEWAY};|
      15s|//.}|}|
      1i acl access { any; };\n
      2a \\\n\tlisten-on { access; };
      2a \\\tallow-query { access; };
      2a \\\tallow-transfer  { none; };
      2a \\\trecursion yes;
      2a \\\tallow-recursion { access; };
    " named.conf.options

    sudo sed -i "
      7a \\\nacl \"inside\" { any; };
      7a \\\nview \"internal\" {
      7a \\\n\tmatch-clients { \"inside\"; };
      7a \\\n\tzone "${DOMAIN}" {
      7a \\\t\ttype master;
      7a \\\t\tfile \"/etc/bind/zones/db.${DOMAIN}\";
      7a \\\t\tallow-update { any; };
      7a \\\t};
      7a \\\n\tzone "${REVERSE_IP}.in-addr.arpa" {
      7a \\\t\ttype master;
      7a \\\t\tfile \"/etc/bind/zones/db.${REVERSE_IP}\";
      7a \\\t};
      7a };
    " named.conf.local

    cd /etc/bind/zones/

    sudo sed -i "
      s|root.localhost.|root.${DOMAIN}.|
      s|localhost.|ns.${DOMAIN}.|g
      12a ns\tIN\tA\t${IP}
      13d
      14d
    " db.${DOMAIN}

    sudo sed -i "
      s|root.localhost.|root.${DOMAIN}.|
      s|localhost.|ns.${DOMAIN}.|g
      12a ${OCTETS[3]}\tIN\tPTR\tns.${DOMAIN}.
      13d
      14d
    " db.${REVERSE_IP}

    sudo systemctl enable named.service
    sudo systemctl start named.service

    sudo systemctl restart bind9; sleep 2; sudo systemctl status bind9

    prints -g "\nDone!\n"
fi

  input_task "Reboot system?"
  if [[ $? -eq 0 ]]; then
    prints -r "\nMachine will be reboot. Press Enter..."; read
    sudo reboot && exit
  fi
}

main "$@"
exit