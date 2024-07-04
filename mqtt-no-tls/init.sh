#!/bin/bash

#set -x
#set -e

# Check for required executables
EXECUTABLES="git docker openssl" #docker-compose pytest-3 
for exec in $EXECUTABLES; do
    which "$exec" > /dev/null || { echo "No $exec in PATH"; exit 1; }
done

MOUNTED_VOLUMES_TOP="mounted_volumes"

# MQTT default user and password for the client
mqtt_user="user"
mqtt_password="password"

#docker compose down --remove-orphans

sudo rm -rf $MOUNTED_VOLUMES_TOP
mkdir -p $MOUNTED_VOLUMES_TOP/mqtt-no-auth/config
mkdir -p $MOUNTED_VOLUMES_TOP/mqtt-with-auth/config


cp mosquitto-no-auth.conf $MOUNTED_VOLUMES_TOP/mqtt-no-auth/config/mosquitto.conf
cp mosquitto-with-auth.conf $MOUNTED_VOLUMES_TOP/mqtt-with-auth/config/mosquitto.conf

touch $MOUNTED_VOLUMES_TOP/mqtt-with-auth/config/passwords.txt

docker run -it --rm -v "$(pwd)"/$MOUNTED_VOLUMES_TOP/mqtt-with-auth/config:/mosquitto/config eclipse-mosquitto mosquitto_passwd -b /mosquitto/config/passwords.txt "$mqtt_user" "$mqtt_password"

docker run -it --rm -v "$(pwd)"/$MOUNTED_VOLUMES_TOP/mqtt-with-auth/config:/mosquitto/config eclipse-mosquitto mosquitto_passwd -b /mosquitto/config/passwords.txt add_new client

docker compose up -d --remove-orphans

#docker run -it --rm -v "$(pwd)"/mounted_volumes/mqtt-with-auth/config:/mosquitto/config eclipse-mosquitto mosquitto_passwd -b /mosquitto/config/passwords.txt add_new client

