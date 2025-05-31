#!/usr/bin/env bash

# COLORS
NC='\033[0m'
SUCCESS='\033[0;32m'
ERROR='\033[0;31m'
WARN='\033[0;33m'
INFO='\033[0;34m'

# SOURCE SETUP.CONF
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
if [[ -f "$SCRIPT_DIR/conf/setup.conf" ]]; then
    source "$SCRIPT_DIR/conf/setup.conf"
fi

echo -e "${INFO}##### Package: Update ${NC}"
apt --assume-yes update

echo -e "${INFO}##### DCP: Install ${NC}"
apt install --assume-yes isc-dhcp-server

echo -e "${INFO}##### DCP: Interface ${NC}"
# BASE_INTERFACE="$(ip link show | grep -E "^[0-9]+:" | awk -F: '{print $2}' | sed 's/^ *//;s/ *$//' | grep -v -e '^lo$' | head -n 1)"
BASE_INTERFACE="$(ip link show | grep -E "^[0-9]+:" | awk -F: '{print $2}' | sed 's/^ *//;s/ *$//' | grep '^ens19$')"
echo -e "\033[1;33m##### Detected base interface: ${BASE_INTERFACE} \033[0m"

echo -e "${INFO}##### DCP: Sub-Interface ${NC}"
SUB_INTERFACE="${BASE_INTERFACE}:1"
ip addr add ${SUB_INTERFACE_IP} dev ${BASE_INTERFACE}
ip link set ${BASE_INTERFACE} up

echo -e "${INFO}##### DCP: Netplan ${NC}"
NETPLAN_FILE=$(find /etc/netplan/ -type f -name "*.yml" | head -n 1)
sed -i "/nameservers:/i \ \ \ \ \ \ - $SUB_INTERFACE_IP" $NETPLAN_FILE
netplan apply

echo -e "${INFO}##### DCP: Configure ${NC}"
echo "d /run/dhcp-server 0755 dhcpd dhcpd -" | tee /etc/tmpfiles.d/dhcpd.conf

echo -e "${INFO}##### DCP: Configure File ${NC}"
echo "$DHCP_CONF_CONTENT" > $DHCP_CONF

echo -e "${INFO}##### DCP: Network ${NC}"
sed -i "s/^INTERFACESv4=.*/INTERFACESv4=\"$BASE_INTERFACE\"/" $INTERFACES_FILE

echo -e "${INFO}##### DCP: Service ${NC}"
systemctl enable isc-dhcp-server
systemctl restart isc-dhcp-server

echo -e "${INFO}##### DCP: Clean ${NC}"
apt --assume-yes autoremove
apt --assume-yes autoclean

echo -e "${SUCCESS}#### DCP: Install Complete ${NC}"

echo -e "${INFO}#### Reboot ${NC}"
#reboot