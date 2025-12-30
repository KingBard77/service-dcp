#!/usr/bin/env bash

set -euo pipefail

# COLORS
NC='\033[0m'
SUCCESS='\033[0;32m'
ERROR='\033[0;31m'
WARN='\033[1;33m'
INFO='\033[1;34m'

# FALSE = run inside VM, TRUE = run remotely via xxclustersh
IS_REMOTE=TRUE

# SOURCE SCRIPT DIRECTORY
if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" != "bash" && "${BASH_SOURCE[0]}" != "-bash" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
else
    SCRIPT_DIR="$(pwd)"
fi

# SOURCE SETUP.CONF
if [[ "$IS_REMOTE" == FALSE ]]; then
    CONFIG_FILE="${SCRIPT_DIR}/conf/setup.conf"
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        echo -e "${ERROR}  ERROR: Missing configuration file: $CONFIG_FILE${NC}"
        exit 1
    fi
fi

# USAGE
usage() {
    echo -e "${INFO}  #####################################################################${NC}"
    echo -e "${INFO}  #                Install (DCP) Service - Usage Guide                #${NC}"
    echo -e "${INFO}  #####################################################################${NC}"
    echo -e ""
    echo -e "${INFO}  Usage:${NC}"
    echo -e "${WARN}    sudo bash -x ./[SCRIPT_NAME]${NC}"
    echo -e ""
    echo -e "${INFO}  Description:${NC}"
    echo -e "    This script installs and configures Dynamic Host Configuration Protocol (DCP) services"
    echo -e ""
    echo -e "${INFO}  Requirements:${NC}"
    echo -e "    - Must be run as root (use sudo)"
    echo -e "    - Make sure conf/setup.conf is present with valid variables"
    echo -e ""
    echo -e "${INFO}  Example:${NC}"
    echo -e "    sudo bash -x ./service-dcp.sh"
    echo -e ""
    exit 1
}

# AGRS FOR HELP USAGE
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

echo -e "${INFO}  ##### Package: Update ${NC}"
apt --assume-yes update

echo -e "${INFO}  ##### DCP: Install ${NC}"
apt install --assume-yes isc-dhcp-server

echo -e "${INFO}  ##### DCP: Interface ${NC}"
BASE_INTERFACE="$(ip link show | grep -E "^[0-9]+:" | awk -F: '{print $2}' | sed 's/^ *//;s/ *$//' | grep '^ens19$')"
echo -e "${WARN}##### Detected base interface: ${BASE_INTERFACE} ${NC}"

echo -e "${INFO}  ##### DCP: Sub-Interface ${NC}"
SUB_INTERFACE="${BASE_INTERFACE}:1"
ip addr add "${DCP_SUB_INTERFACE_IP}" dev "${BASE_INTERFACE}"
ip link set "${BASE_INTERFACE}" up

echo -e "${INFO}  ##### DCP: Netplan ${NC}"
NETPLAN_FILE=$(find /etc/netplan/ -type f -name "*.yml" | head -n 1)
sed -i "/nameservers:/i \ \ \ \ \ \ - ${DCP_SUB_INTERFACE_IP}" "$NETPLAN_FILE"
netplan apply

echo -e "${INFO}  ##### DCP: Configure Runtime ${NC}"
echo "d /run/dhcp-server 0755 dhcpd dhcpd -" | tee /etc/tmpfiles.d/dhcpd.conf

echo -e "${INFO}  ##### DCP: Configure DHCPD File ${NC}"
echo "$DCP_CONF_CONTENT" > "$DCP_CONF_FILE"

echo -e "${INFO}  ##### DCP: Set DHCP Interface ${NC}"
sed -i "s/^INTERFACESv4=.*/INTERFACESv4=\"${BASE_INTERFACE}\"/" "$DCP_INTERFACES_FILE"

echo -e "${INFO}  ##### DCP: Service ${NC}"
systemctl enable isc-dhcp-server
systemctl restart isc-dhcp-server

echo -e "${INFO}  ##### DCP: Clean ${NC}"
apt --assume-yes autoremove
apt --assume-yes autoclean

echo -e "${SUCCESS}#### DCP: Install Complete ${NC}"

echo -e "${INFO}#### Reboot ${NC}"
# reboot
