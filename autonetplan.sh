#!/bin/bash
[ "$UID" -eq 0 ] || exec sudo "$0" "$@"
echo "initial setup parameters are required to continue"
adapter=$(ip route get 8.8.8.8 | awk '{print $5}')
echo "Using active network adapter: $adapter"

# Function to validate IP address format
function validate_ip() {
    local ip="$1"
    # Regular expression to check IP address format
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        return 0  # IP address format is valid
    else
        return 1  # IP address format is invalid
    fi
}

# Function to validate subnet format
function validate_subnet() {
    local subnet="$1"
    # Regular expression to check subnet format (e.g., 24, 16, etc.)
    if [[ "$subnet" =~ ^[0-9]{1,2}$ ]]; then
        return 0  # Subnet format is valid
    else
        return 1  # Subnet format is invalid
    fi
}

# Function to validate gateway format
function validate_gateway() {
    local gateway="$1"
    # Validate gateway IP format
    if validate_ip "$gateway"; then
        return 0  # Gateway format is valid
    else
        return 1  # Gateway format is invalid
    fi
}

# Function to validate nameserver format
function validate_nameserver() {
    local nameserver="$1"
    # Validate nameserver IP format
    if validate_ip "$nameserver"; then
        return 0  # Nameserver format is valid
    else
        return 1  # Nameserver format is invalid
    fi
}

# Prompt the user for network configuration information
read -p "Enter the IP address: " ip_address
while ! validate_ip "$ip_address"; do
    read -p "Invalid IP address format. Please try again: " ip_address
done

read -p "Enter the subnet (e.g., 24, 16, etc.): " subnet
while ! validate_subnet "$subnet"; do
    read -p "Invalid subnet format. Please try again: " subnet
done

read -p "Enter the gateway IP address: " gateway
while ! validate_gateway "$gateway"; do
    read -p "Invalid gateway IP format. Please try again: " gateway
done

# Prompt for nameservers (can be multiple, separated by spaces)
read -p "Enter the nameserver(s) IP addresses (separated by spaces if multiple): " nameservers
IFS=' ' read -ra nameserver_array <<< "$nameservers"
for nameserver in "${nameserver_array[@]}"; do
    while ! validate_nameserver "$nameserver"; do
        read -p "Invalid nameserver IP format. Please try again: " nameserver
    done
done

# Create the Netplan configuration file
cat >netplan_yaml <<EOL
network:
  version: 2
  renderer: networkd
  ethernets:
    $adapter:
      addresses: [$ip_address/$subnet]
      nameservers:
        addresses: [$nameservers]
      routes:
      - to: default
        via: $gateway
EOL


sudo cat netplan_yaml > /etc/netplan/00-installer-config.yaml
sudo netplan apply

