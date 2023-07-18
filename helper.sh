#!/bin/bash

#used vars
##COMPOSE_FILE
##MQTT_COMPOSE_FILE
##line
##new_line
##new_tag
##response

echo "███████╗████████╗██╗      ███████╗██╗  ██╗ ██████╗ ██╗  ██╗"
echo "██╔════╝╚══██╔══╝██║      ██╔════╝██║  ██║██╔═══██╗██║ ██╔╝"
echo "███████╗   ██║   ██║█████╗███████╗███████║██║   ██║█████╔╝ "
echo "╚════██║   ██║   ██║╚════╝╚════██║██╔══██║██║   ██║██╔═██╗ "
echo "███████║   ██║   ███████╗ ███████║██║  ██║╚██████╔╝██║  ██╗"
echo "╚══════╝   ╚═╝   ╚══════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝"
                                                         

if [[ $# -eq 0 || "$1" == "--help" ]]; then
echo "HELP"
echo "commands available:"
echo -e "\033[32mAVP Section\033[0m"
echo "--pull        			pulls build specified in avp_compose.yaml"
echo "--down        			stops running container spawned by avp_compose.yaml"
echo "--up          			starts container using avp_compose.yaml"
echo "--update-build 			prompts user for build change"
echo ""
echo -e "\033[33mMQTT Stack\033[0m"
echo "--mqtt-up			starts mqtt stack"
echo "--mqtt-down			stops mqtt stack"
echo "--mqtt-purge			purges zigbee and mqtt config and sensor data"
echo ""
echo -e "\033[36mNetwork\033[0m"
echo "--network			checks if the shadownet network is present, if not, creates it"
echo ""
exit 0
fi


# Check if container is running
if docker ps --format '{{.Names}}' | grep -q shadownet_avp; then
  echo -e "Container shadownet_avp is \033[32m running\033[0m."
else
  echo -e "Container shadownet_avp is not \033[31mrunning\033[0m."
fi


# Set the name of your Docker Compose file
COMPOSE_FILE=avp_compose.yaml
MQTT_COMPOSE_FILE=zigbee_mqtt_compose.yaml

# Check if the --pull argument was passed in
if [[ "$1" == "--pull" ]]; then
  # Pull the latest images for all services - checks to see if its running first
  if docker ps --format '{{.Names}}' | grep -q shadownet_avp; then
    echo -e "Container shadownet_avp is \033[32m running\033[0m. Stopping before pull."
    docker-compose -f $COMPOSE_FILE down
  else
    docker-compose -f $COMPOSE_FILE pull
    docker-compose -f $COMPOSE_FILE up -d
  fi

  elif [[ "$1" == "--down" ]]; then
  docker-compose -f $COMPOSE_FILE down
  
  elif [[ "$1" == "--up" ]]; then
  docker-compose -f $COMPOSE_FILE up -d

  elif [[ "$1" == "--update-build" ]]; then
  # Find line starting with "image:"
		line=$(grep -m 1 "image:" $COMPOSE_FILE)

		# Display the entire line
		echo "Build found: $line"

		# Prompt user for input
		read -p "Do you want to change the build? [y/n] " response

		if [[ "$response" =~ ^[Yy]$ ]]; then
			# Extract the current image tag
			image_tag=$(echo $line | cut -d: -f2)

			# Prompt user for new image tag
			read -p "Enter new build tag: " new_tag

			# Replace the image tag in the line
			new_line="    image: $new_tag"

			# Replace the line in the file
			sed -i "s#$line#$new_line#g" $COMPOSE_FILE

			echo "Build updated: $new_line"
		else
			echo "Build not changed."
		fi


# MQTT Portion
  elif [[ "$1" == "--mqtt-up" ]]; then
  docker-compose -f $MQTT_COMPOSE_FILE up -d

  elif [[ "$1" == "--mqtt-purge" ]]; then
		echo -e "\033[31mWarning! This will delete all sensors and require them to be manually re-added!\033[0m"
		read -p "Do you want to continue? [y/n] " response
			if [[ "$response" =~ ^[Yy]$ ]]; then
	  		docker-compose -f $MQTT_COMPOSE_FILE down
				rm -r zigbee2mqtt-data mosquitto-data
				echo "zigbee and mqtt config and sensor data purged"
				docker-compose -f $MQTT_COMPOSE_FILE up -d
			else
				echo "no action taken"
			fi
  elif [[ "$1" == "--mqtt-down" ]]; then
  docker-compose -f $MQTT_COMPOSE_FILE down

# Network Portion
  elif [[ "$1" == "--network" ]]; then
  if docker ps --format '{{.Names}}' | grep -q shadownet; then
    echo -e "Network shadownet is \033[32m established\033[0m."
  else
    echo -e "Network shadownet is not \033[31mestbalished\033[0m."
      docker network create -d ipvlan --subnet=10.0.0.0/24 --gateway=10.0.0.1 -o ipvlan_mode=l2 -o parent=enp1s0 shadownet
  fi

else
echo "ambigous command" 
fi

