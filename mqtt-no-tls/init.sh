#!/bin/bash

#set -x
#set -e

# Check for required executables
EXECUTABLES="git docker openssl" 
for exec in $EXECUTABLES; do
    which "$exec" > /dev/null || { echo "No $exec in PATH"; exit 1; }
done

MOUNTED_VOLUMES_TOP="mounted_volumes"

# Check if the mounted volumes directory exists and in particular the mounted volumes for the MQTT broker with authentication
if [ -d "$MOUNTED_VOLUMES_TOP" ]; then
    if [ -f "$MOUNTED_VOLUMES_TOP/mqtt-with-auth/config/passwords.txt" ]; then
        echo "Attention: the passowrd file already exists. Please remove it before starting the MQTT broker with this script. Make sure to backup the file if needed."
        exit 1
    fi
fi

# Function to start MQTT broker without authentication
start_mqtt_no_auth() {
    mkdir -p $MOUNTED_VOLUMES_TOP/mqtt-no-auth/config
    cp mosquitto-no-auth.conf $MOUNTED_VOLUMES_TOP/mqtt-no-auth/config/mosquitto.conf
    echo "Starting MQTT broker without authentication..."
    docker compose -f docker-compose_no-auth.yaml up -d --remove-orphans
}

# Function to start MQTT broker with authentication
start_mqtt_with_auth() {

    # MQTT default user and password for the client
    mqtt_user="user"
    mqtt_password="password"

    # Create the mounted volumes for the "with-auth" setup and copy the configuration files
    mkdir -p $MOUNTED_VOLUMES_TOP/mqtt-with-auth/config
    cp mosquitto-with-auth.conf $MOUNTED_VOLUMES_TOP/mqtt-with-auth/config/mosquitto.conf

    # Initialize password file for the "with-auth" setup
    touch $MOUNTED_VOLUMES_TOP/mqtt-with-auth/config/passwords.txt

    # Set default passwords for the "with-auth" mode
    docker run -it --rm -v "$(pwd)"/$MOUNTED_VOLUMES_TOP/mqtt-with-auth/config:/mosquitto/config eclipse-mosquitto mosquitto_passwd -b /mosquitto/config/passwords.txt "$mqtt_user" "$mqtt_password"
    docker run -it --rm -v "$(pwd)"/$MOUNTED_VOLUMES_TOP/mqtt-with-auth/config:/mosquitto/config eclipse-mosquitto mosquitto_passwd -b /mosquitto/config/passwords.txt add_new client
        
    echo "Starting MQTT broker with authentication..."
    docker compose -f docker-compose_with-auth.yaml up -d --remove-orphans
}

chose (){
    # Choose mode based on user input or some condition
    echo "Choose the mode to start the MQTT broker:"
    echo "1. No authentication"
    echo "2. With authentication"

    read -p "Choose the mode ((number): " mode
    case $mode in
        1)
            start_mqtt_no_auth
            ;;
        2)
            start_mqtt_with_auth
            ;;
        *)
            echo "Invalid mode selected. Please choose 'no-auth' or 'with-auth'."
            exit 1
            ;;
    esac
}

# Check if the script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # The script is being executed, call choose function
    choose
fi
