#!/bin/bash

## The super premium docker setup script by Shane mf' Davis


[ "$UID" -eq 0 ] || exec sudo "$0" "$@"



echo -e "\033[31m███████╗████████╗██╗      ███████╗██╗  ██╗ ██████╗ ██╗  ██╗\033[0m"
echo -e "\033[37m██╔════╝╚══██╔══╝██║      ██╔════╝██║  ██║██╔═══██╗██║ ██╔╝\033[0m"
echo -e "\033[34m███████╗   ██║   ██║█████╗███████╗███████║██║   ██║█████╔╝ \033[0m"
echo -e "\033[31m╚════██║   ██║   ██║╚════╝╚════██║██╔══██║██║   ██║██╔═██╗ \033[0m"
echo -e "\033[37m███████║   ██║   ███████╗ ███████║██║  ██║╚██████╔╝██║  ██╗\033[0m"
echo -e "\033[34m╚══════╝   ╚═╝   ╚══════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝\033[0m"
echo -e "\033[1;32m  Influence.           Observe.                Dominate.   \033[0m"



#installing dependancies 
apt update && apt install docker.io docker-compose -y

#making directory and moving contents
mkdir -p /software/docker
mv -- * /software/docker
cd /software/docker || exit 
chmod +x helper.sh
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
while true; do
    read -p "Enter your Docker Hub username: " username
    read -s -p "Enter your Docker Hub password: " password
    
    # Attempt to log in to Docker Hub
    echo "$password" | docker login --username "$username" --password-stdin

    # Check if the login was successful
    if [ $? -eq 0 ]; then
        break
    else
        echo "Login failed. Please check your credentials and try again."
    fi
done


### initial setup data
### network data
echo "initial setup parameters are required to continue"
adapter=$(ip route get 8.8.8.8 | awk '{print $5}')
echo -e "\033[32mUsing active network adapter:\033[0m" " \033[33m$adapter\033[0m"

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

# Zigbee Support Option
yes_no "Do you want to add Zigbee support?"
if [ "$is_true" = "true" ]; then
    # Search for a device containing the word "Sonoff" in /dev/serial/by-id/
    sonoff_device=$(find /dev/serial/by-id/ -type l -name "*Sonoff*" 2>/dev/null) 
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
    # Ask the user for the username and password for the MQTT Broker
        read -p "Enter the desired username for the MQTT Broker: " mqtt_broker_user
        read -p "Enter the desired password for the MQTT Broker: " mqtt_broker_pass
    #Perform conifg file edits
    sed -i "s,zigbee2mqtt_ip,$zigbee2mqtt_ip,g" $MQTT_COMPOSE_FILE 
    sed -i "s,mqtt_broker_ip,$mqtt_broker_ip,g" $MQTT_COMPOSE_FILE
    sed -i "s,mqtt_broker_ip,$mqtt_broker_ip,g" zigbee2mqtt-data/configuration.yaml
    sed -i "s,mqtt_broker_user,$mqtt_broker_user,g" zigbee2mqtt-data/configuration.yaml
    sed -i "s,mqtt_broker_pass,$mqtt_broker_pass,g" zigbee2mqtt-data/configuration.yaml
    # Check if any matching device was found
    if [ -n "$sonoff_device" ]; then
      echo "Sonoff device found: $sonoff_device"
      #format text and insert into config file
      sed -i "s,sonoff,$sonoff_device,g" $MQTT_COMPOSE_FILE
    else
      sudo sed -i '/devices:/,+1d' $MQTT_COMPOSE_FILE 
      echo -e "\033[31mWarning! No Sonoff USB device found. The device will need manually configured.\033[0m" || break
    fi
    echo -e "\033[32mMQTT settings applied.\033[0m"
    mqtt_set=1
fi


#create shadownet-network
docker network create -d ipvlan --subnet=$subnet --gateway=$docker_gateway -o ipvlan_mode=l2 -o parent=$adapter shadownet

#update config files
sed -i "s,shadownetavp_ip,$shadownetavp_ip,g" $COMPOSE_FILE
sed -i "s,dgateway,$docker_gateway,g" helper.sh
sed -i "s,dsubnet,$subnet,g" helper.sh
sed -i "s,dadapter,$adapter,g" helper.sh
echo -e "\033[32mShadownet settings applied.\033[0m"

#image pull and start
echo -e "\033[32mDownloading and starting applications...\033[0m"
if [ "$mqtt_set" = 1 ]; then 
    docker-compose -f $MQTT_COMPOSE_FILE up -d
fi
docker-compose -f $COMPOSE_FILE up -d

echo -e "\033[32m*fin\033[0m"
