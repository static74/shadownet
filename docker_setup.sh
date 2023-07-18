#!/bin/bash
[ "$UID" -eq 0 ] || exec sudo "$0" "$@"

#installing dependancies 
apt update && apt install docker.io docker-compose -y

#making directory and moving contents
git clone https://github.com/static74/shadownet
mkdir -p /software/docker
mv shadownet/* /software/docker
rm -rf shadownet
cd /software/docker || exit 
chmod +X helper.sh
COMPOSE_FILE=avp_compose.yaml
MQTT_COMPOSE_FILE=zigbee_mqtt_compose.yaml

##FUNCTIONS###
# Function to validate the CIDR format
function validate_cidr() {
    local cidr="$1"
    # Regular expression to check CIDR format (e.g., 192.168.0.0/24)
    if [[ "$cidr" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        return 0  # CIDR format is valid
    else
        return 1  # CIDR format is invalid
    fi
}
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

# Function to read user input and set the variable to true if the response is yes
function yes_no() {
    local question="$1"
    local response

    while true; do
        read -p "$question (yes/no): " response
        case "$response" in
            [Yy][Ee][Ss]) is_true=true; return ;;
            [Nn][Oo]) return ;;
            *) echo "Invalid response. Please enter 'yes' or 'no'." ;;
        esac
    done
}

# Function for docker login
function docker_login() {
    read -p "Enter your Docker Hub username: " username
    read -s -p "Enter your Docker Hub password: " password
    echo

    # Attempt to log in to Docker Hub
    echo "$password" | docker login --username "$username" --password-stdin

    # Check if the login was successful
    if [ $? -eq 0 ]; then
        echo "Login successful!"
        exit 0
    else
        echo "Login failed. Please check your credentials and try again."
    fi
}


### initial setup data
### network data
echo "initial setup parameters are required to continue"
adapter=$(ip route get 8.8.8.8 | awk '{print $5}')
echo "Using active network adapter: $adapter"

# Ask the user for the docker subnet in CIDR format
while true; do
    read -p "Enter the Docker network subnet in CIDR format (e.g., 192.168.0.0/24):" subnet
    if validate_cidr "$subnet"; then 
        break
    else
        echo "Invalid CIDR format. Please try again."
    fi
done

# Ask the user for the docker network gateway
while true; do
    read -p "Enter Docker network gateway IP address: " docker_gateway
    if validate_ip "$docker_gateway"; then
        break
    else
        echo "Invalid IP address format. Please try again."
    fi
done

# Ask the user for the shadownet_avp server IP
while true; do
    read -p "Enter shadownet_avp container IP address: " shadownetavp_ip
    if validate_ip "$shadownetavp_ip"; then
        break
    else
        echo "Invalid IP address format. Please try again."
    fi
done

# Docker login
echo "credentials required to log into docker repository"
while true; do
    docker_login
done

# Ask the user for the zigbee2mqtt server IP
while true; do
    read -p "Enter zigbee2mqtt container IP address: " zigbee2mqtt_ip
    if validate_ip "$zigbee2mqtt_ip"; then
        break
    else
        echo "Invalid IP address format. Please try again."
    fi
done

# Ask the user for the mqtt_broker server IP
while true; do
    read -p "Enter mqtt_broker container IP address: " mqtt_broker_ip
    if validate_ip "$mqtt_broker_ip"; then
        break
    else
        echo "Invalid IP address format. Please try again."
    fi
done

# Docker login
echo "credentials required to log into docker repository"
while true; do
    docker_login
done


# Zigbee Support Option
yes_no "Do you want to add Zigbee support?"
if [ "$is_true" = "true" ]; then
    # Search for a device containing the word "Sonoff" in /dev/serial/by-id/
    sonoff_device=$(find /dev/serial/by-id/ -type l -name "*Sonoff*")
    
    # Check if any matching device was found
    if [ -n "$sonoff_device" ]; then
      echo "Sonoff device found: $sonoff_device"
      #format text and insert into config file
      sed -i "s,dongle,       - $sonoff_device,g" $MQTT_COMPOSE_FILE
    else
      echo "No Sonoff device found. Skipping." || break
    fi
fi


#create shadownet-network
docker network create -d ipvlan --subnet=$subnet --gateway=$docker_gateway -o ipvlan_mode=l2 -o parent=$adapter shadownet

sed -i "s,shadownetavp_ip,$shadownetavp_ip,g" $COMPOSE_FILE
sed -i "s,zigbee2mqtt_ip,$zigbee2mqtt_ip,g" $MQTT_COMPOSE_FILE 
sed -i "s,mqtt_broker_ip,$mqtt_broker_ip,g" $MQTT_COMPOSE_FILE
sed -i "s,dgateway,$docker_gateway,g" helper.sh
sed -i "s,dsubnet,$subnet,g" helper.sh
sed -i "s,dadapter,$adapter,g" helper.sh

echo "networks created"

#assign ip addresses to the container
sed -i "s,shadownetavp_ip,$shadownetavp_ip,g" $COMPOSE_FILE


#image pull
docker-compose -f $COMPOSE_FILE pull
docker-compose -f $MQTT_COMPOSE_FILE pull

echo "done" 