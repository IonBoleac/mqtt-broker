#!/bin/bash

#set -x
#set -e
# Functions to handle verbosity of the script. Add Q_STDOUT and Q_STDERR to the end of the command to suppress output.
# At the moment, the script isn't set up to handle the output. 
# Example: docker compose up $Q_STDOUT or $Q_STDERR
# Doesn't work (must be reviewed)
V=1
Q_STDOUT="> /dev/null"
Q_STDERR="2> /dev/null"

# If whant to see the output of the commands set V=1
if [ "$V" -ne 0 ]; then
    Q_STDOUT=
    Q_STDERR="2>> error.log"
fi

# =================Logging=================
# Log file path and the log directory path
WARNING="Warning"
ERROR="Error"
INFO="Info"
EVENT="Event"

LOG_DIR="./logs"
LOG_TIME=$(date +"%Y-%m-%d")
[ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$LOG_TIME-log.log"

# Function to log messages. Usage: log <level> <message>
log() {
    local command_name=$(basename "$0")
    local message="$1"
    local level="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    level=${level:-$INFO}
    echo "$timestamp - $level - $message"
    echo "$timestamp - $level - $command_name - $message" >> "$LOG_FILE"
}

# =================Variable Definitions=================
GIT_VERSION=$(git describe --abbrev=6 --dirty --always --tags)
GIT_VERSION=${GIT_VERSION:-"No version"}
MOUNTED_VOLUMES_TOP="mounted_volumes"

# Name of the Docker container for the MQTT broker seted in the docker-compose.yml file. Must be the same
DOCKER_CONTAINER_NAME="mqtt-tls"

# Docker image to use to run when is neede to add or delete a user from the MQTT server
DOCKER_IMAGE="eclipse-mosquitto:2.0.18"

# Data for the certs
# Materials that go in the subject
IP_BROKER=localhost # Change this to the IP of the broker or better with the domain name
ORGANIZATION_NAME=mechlav.com # Change this to the name of your organization

# NOTE: the Common Name (CN) for the CA must be different than that of the broker and the client
SUBJECT_ROOT_CA="/C=IT/ST=Italy/L=Italy/O=$ORGANIZATION_NAME/OU=CA/CN=$ORGANIZATION_NAME"
SUBJECT_SERVER="/C=IT/ST=Italy/L=Italy/O=$ORGANIZATION_NAME/OU=Broker/CN=$IP_BROKER"

# BROKER certificates
BROKER_KEY="mqtt/certs/broker/broker.key"
BROKER_CSR="mqtt/certs/broker/broker.csr"
BROKER_CRT="mqtt/certs/broker/broker.crt"

# CA certificates
CA_KEY="mqtt/certs/ca/ca.key"
CA_CRT="mqtt/certs/ca/ca.crt"

# =================Pre-checks=================
# Check if the CA certificates and the broker certificates exist
check_CA_and_broker_certificates() {
    if [[ ! -f $CA_CRT || ! -f $CA_KEY || ! -f $BROKER_CRT || ! -f $BROKER_KEY ]]; then
        log "check_CA_and_broker_certificates - The CA certificates and the broker certificates are missing" $ERROR
        exit 1
    fi
    
}

# Check if in the mounted volumes are the directories and the files needed for the MQTT broker
check_mounted_volumes() {
    if [[      ! -d "$MOUNTED_VOLUMES_TOP/mqtt/config/certs" 
            || ! -d "$MOUNTED_VOLUMES_TOP/mqtt/data" 
            || ! -f "$MOUNTED_VOLUMES_TOP/mqtt/config/mosquitto.conf" 
            || ! -f "$MOUNTED_VOLUMES_TOP/mqtt/config/passwords.txt" 
            || ! -f "$MOUNTED_VOLUMES_TOP/mqtt/config/certs/broker.crt" 
            || ! -f "$MOUNTED_VOLUMES_TOP/mqtt/config/certs/broker.key"
            || ! -f "$MOUNTED_VOLUMES_TOP/mqtt/config/certs/ca.crt"
        ]]; then
        log "check_mounted_volumes - The directories and the files needed for the MQTT broker are missing in the mounted volumes" $ERROR
        exit 1
    fi
}

# Check for required executables
check_executables() {
    EXECUTABLES="nohup git docker openssl" #docker-compose pytest-3 
    for exec in $EXECUTABLES; do
        which "$exec" > /dev/null || { log $ERROR "No $exec in PATH"; exit 1; }
    done
}

# Check if Docker is running
check_docker() {
    # cher if docker is running
    if ! docker info > /dev/null 2>&1; then
        log "check_docker - Docker is not running" $ERROR
        exit 1
    fi
}

# Check if the container is running
check_docker_container() {
    # Check if the container is running
    local running
    running=$(docker container ps -a | grep -c $DOCKER_CONTAINER_NAME)
    if [ "$running" -eq '0' ]; then
        return 0
    fi
    return "$running"
}

# Check if the DN is in the correct format
validate_dn() {
    local dn="$1"
    #local pattern='^(/C=[A-Z]{2})?(/ST=[^/]+)?(/L=[^/]+)?(/O=[^/]+)?(/OU=[^/]+)?(/CN=[^/]+)?$'
    local pattern='^/C=[A-Z]{2}/ST=[^/]+/L=[^/]+/O=[^/]+/OU=[^/]+/CN=[^/]+$'
    
    if [[ $dn =~ $pattern ]]; then
        log "validate_dn - Valid DN: $dn"
        return 1
    else
        log "validate_dn - Invalid DN: $dn" $ERROR
        return 0
    fi
}

# Check if the user is already in the password file
if_exist_user() {
    local MQTT_USER=$1
    # control if the user is already in the password file
    if grep -q "$MQTT_USER" "$MOUNTED_VOLUMES_TOP/mqtt/config/passwords.txt"; then
        log "if_exist_user - User $MQTT_USER already exists in the password file" $ERROR 
        exit 1
    fi
}

# Set permissions and ownership for the passwords file (not used at the moment)
set_permissions_and_ownership() {
    return
    # Set permissions and ownership for the passwords file
    #sudo chmod 0700 "$MOUNTED_VOLUMES_TOP/mqtt/config/passwords.txt"
    #sudo chown root:root "$MOUNTED_VOLUMES_TOP/mqtt/config/passwords.txt"
}

# =================DEFINE OPTIONS AS FUNCTIONS=================
# Initialize the environment
function init {
    log "init - Initializing the environment creating the directories and copying the configuration files needed for MQTT broker"
    # MQTT directories setup
    [ ! -d "$MOUNTED_VOLUMES_TOP/mqtt/config/certs" ] && mkdir -p "$MOUNTED_VOLUMES_TOP/mqtt/config/certs"
    [ ! -d "$MOUNTED_VOLUMES_TOP/mqtt/data" ] && mkdir -p "$MOUNTED_VOLUMES_TOP/mqtt/data"

    # Copy MQTT config if not exists
    [ ! -f "$MOUNTED_VOLUMES_TOP/mqtt/config/mosquitto.conf" ] && cp "mqtt/mosquitto.conf" "$MOUNTED_VOLUMES_TOP/mqtt/config/mosquitto.conf"

    # Create the password file
    [ ! -f "$MOUNTED_VOLUMES_TOP/mqtt/config/passwords.txt" ] && touch "$MOUNTED_VOLUMES_TOP/mqtt/config/passwords.txt"

    # Set permissions and ownership for the passwords file
    set_permissions_and_ownership
}

# Clean only the mounted volumes without removing the certificates
function clean {
    log "clean - Removing the $MOUNTED_VOLUMES_TOP directories."
    # Check if the container is running
    check_docker_container
    if [ "$?" -ne '0' ]; then
        log "clean - The container $DOCKER_CONTAINER_NAME is running. Stop the container before cleaning the mounted volumes" $ERROR
    else
        sudo rm -rf $MOUNTED_VOLUMES_TOP
    fi
}

# Deep clean the application removing all the certificates and the mounted volumes
function deep_clean {
    log "deep_clean - Deep cleaning the application removing all the certificates and the mounted volumes and eventualy delete the broker."

    check_docker_container
    if [ "$?" -ne '0' ]; then
        stop
    fi

    # Check if there are mounted volumes
    if [ -d "$MOUNTED_VOLUMES_TOP" ]; then
        clean
    fi

    # Deleting specific file types in ca, broker, and clients directories
    sudo find mqtt/certs/ca/ -type f \( -name "*.crt" -o -name "*.key" -o -name "*.srl" \) -exec rm -f {} +
    sudo find mqtt/certs/broker/ -type f \( -name "*.crt" -o -name "*.key" -o -name "*.csr" \) -exec rm -f {} +
    sudo find mqtt/certs/clients/ -type f \( -name "*.crt" -o -name "*.key" -o -name "*.csr" \) -exec rm -f {} +
    # Deleting directories in clients directory
    sudo find mqtt/certs/clients/ -mindepth 1 -type d -exec rm -rf {} +
}

# Create all the certificates: CA and the certificates for the MQTT clients
function generate_client_certificates {
    # ================== CLIENT ==================
    local CLIENT_FILE="$1"
    log "generate_client_certificates - Creating client certificate for $CLIENT_FILE" $EVENT

    # Check required files
    if [[ ! -f $CA_CRT || ! -f $CA_KEY || ! -f "${MOUNTED_VOLUMES_TOP}/mqtt/config/passwords.txt" ]]; then
        log "generate_client_certificates - Required files $CA_CRT, $CA_KEY and ${MOUNTED_VOLUMES_TOP}/mqtt/config/passwords.txt are missing. There are missing files for the CA certificate and the passwords.txt file." $ERROR
        exit 1
    fi

    # Read data from the client file
    IFS=';' read -r summary mqtt_user mqtt_password validity < "${CLIENT_FILE}"
    
    if [[ -z $summary || -z $mqtt_user || -z $mqtt_password ]]; then
        log "generate_client_certificates - The client file is not in the correct format. The format must be: summary;mqtt_user;mqtt_password" $ERROR
        exit 1
    fi

    # Check if the user is already in the password file
    #if_exist_user "$mqtt_user"
    # Check if the validity is set or set the default valu and after this check if is a number
    validity=${validity:-365}
    if ! [[ "$validity" =~ ^[0-9]+$ ]]; then
        log "generate_client_certificates_CLI - Validity isn't in correct format. Must be a non-null integer." $ERROR
        exit 1
    fi

    # Check if the subject is in the correct format
    log "generate_client_certificates - Creating Client: ${mqtt_user} with validity: $validity days" 
    validate_dn "$summary"
    if [ "$?" -eq '1' ]; then
        generate_client_certificates_CLI "$mqtt_user" "$mqtt_password" "$summary" "$validity"
    else 
        log "generate_client_certificates - The subject is not in the correct format" $ERROR
    fi
}

# Create the certificates for the MQTT clients from the command line in the forma: username password subject
function generate_client_certificates_CLI {
    # ================== CLIENT ==================
    local CLIENT="$1"
    local CLIENT_PASSWORD="$2"
    local CLIENT_SUBJECT="$3"
    local VALIDITY="$4"

    # Check if the validity is set or set the default valu and after this check if is a number
    VALIDITY=${VALIDITY:-365}
    if ! [[ "$VALIDITY" =~ ^[0-9]+$ ]]; then
        log "generate_client_certificates_CLI - Validity isn't in correct format. Must be a non-null integer." $ERROR
        exit 1
    fi

    local CLIENT_PATH="mqtt/certs/clients/$CLIENT/$CLIENT"
    log "generate_client_certificates_CLI - Creating client certificate for $CLIENT with validity: $VALIDITY days" 

    # Create the directorie for the client
    mkdir -p mqtt/certs/clients/"$CLIENT"
    
    # Check required files
    if [[ ! -f $CA_CRT || ! -f $CA_KEY || ! -f "${MOUNTED_VOLUMES_TOP}/mqtt/config/passwords.txt" ]]; then
        log "generate_client_certificates_CLI - Required files are missing. There are missing files for the CA certificate and the passwords.txt file." $ERROR
        exit 1
    fi

    # Generate RSA key
    openssl genrsa -out "${CLIENT_PATH}.key" 

    # Create CSR
    openssl req -new -key "${CLIENT_PATH}.key" -out "${CLIENT_PATH}.csr" -subj "${CLIENT_SUBJECT}" || openssl req -in "${CLIENT_PATH}.csr" -noout -text

    # Sign the certificate
    openssl x509 -req -CA $CA_CRT -CAkey $CA_KEY -CAcreateserial -in "${CLIENT_PATH}.csr" -out "${CLIENT_PATH}.crt" || openssl x509 -in "${CLIENT_PATH}.crt" -days "$VALITITY" -text -noout

    # Update MQTT user passwords
    docker run -it --rm -v "$(pwd)"/$MOUNTED_VOLUMES_TOP/mqtt/config:/mosquitto/config $DOCKER_IMAGE mosquitto_passwd -b /mosquitto/config/passwords.txt "$CLIENT" "$CLIENT_PASSWORD"
}

# Create the certificates for the MQTT broker, the CA and the existed clients
function create_certs {
    # Check if the CN's broker and CA are in the correct format
    validate_dn "$SUBJECT_ROOT_CA"
    validate_dn "$SUBJECT_SERVER"

    # ================== CA ==================
    log "create_certs - ===Creating CA certificate===" $EVENT

    # KEY: Generate the CA private key
    # Note: if you want a password protected key, then add the '-des3'
    # command line option to the 'openssl genrsa' command below.
    openssl genrsa -out $CA_KEY 4096 # Create the CA private key

    # CERTIFICATE: Generate the self-signed CA certificate
    # Here we used our root key to create the root certificate that needs
    # to be distributed in all the computers that have to trust us.
    openssl req -x509 -new -nodes -key $CA_KEY -sha256 -days 1024 -out $CA_CRT -subj "$SUBJECT_ROOT_CA" # Create the CA certificate
    
    # ================== BROKER ==================
    log "create_certs - ===Creating BROKER certificate===" $EVENT
    

    # KEY: Generate the broker private key
    openssl genrsa -out $BROKER_KEY 2048 # Create the broker private key

    # CERTIFICATE SIGNING REQUEST (CSR): Generate the broker certificate signing request
    # The certificate signing request is where you specify the details for
    # the certificate you want to generate.  This request will be
    # processed by the owner of the Root key (you in this case since you
    # created it earlier) to generate the certificate.
    openssl req -new -key $BROKER_KEY -out $BROKER_CSR -subj "$SUBJECT_SERVER" || openssl req -in $BROKER_CSR -noout -text  # C              reate the broker certificate signing request

    # CERTIFICATE: Generate the broker's certificate
    openssl x509 -req -in $BROKER_CSR -CA $CA_CRT -CAkey $CA_KEY -CAcreateserial -out $BROKER_CRT -days 500 -sha256 || openssl x509 -in $BROKER_CRT -text -noout

    # ================== CLIENT ==================
    log "create_certs - ===Creating CLIENT certificate==="
    CLIENT_FILEs=$(ls mqtt/certs/clients/*.client)
    log "create_certs - There are $(echo "$CLIENT_FILEs" | wc -w) clients to create"
    for file in $CLIENT_FILEs; do
        generate_client_certificates "$file"
    done

    # copy the needed PEM files to the mounted volumes
    log "create_certs - Copying the certificates to the $MOUNTED_VOLUMES_TOP"
    sudo cp -f $CA_CRT $MOUNTED_VOLUMES_TOP/mqtt/config/certs/ca.crt
    sudo cp -f $BROKER_CRT $MOUNTED_VOLUMES_TOP/mqtt/config/certs/broker.crt
    sudo cp -f $BROKER_KEY $MOUNTED_VOLUMES_TOP/mqtt/config/certs/broker.key
}


# Start the application with a clean start that cleans the mounted volumes, initializes the environment, creates the certificates and starts the application
function clean_start {
    # Check if the application is already running (assume that docker is not used for other applications)
    local running
    check_docker_container
    running=$?
    log "clean_start - Starting the application with a clean start. Cleaning the mounted volumes, initializing the environment, creating the certificates and starting the application"
    if [ "$running" -eq '0' ]; then
        deep_clean
        init
        create_certs
        nohup docker compose up -d &
        set_permissions_and_ownership
        log "clean_start - Application Started: VERSION $GIT_VERSION"
    else
        log "clean_start - Already running" $WARNING
        docker compose ps
        false
    fi
}

# Start the application only with the docker compose up command. The certificates must be created before.
function start {
    log "start - Starting the application with only the docker compose up command. The certificates must be created before"
    # Check if the application is already running (assume that docker is not used for other applications)
    local running
    check_docker_container
    running=$?
    if [ "$running" -eq '0' ]; then
        check_mounted_volumes
        nohup docker compose up -d &
        log "start - Application Started - VERSION $GIT_VERSION"
    else
        log "start - Already running" $WARNING
        docker compose ps
        false
    fi
}

# Stop the application with the docker compose down command that remove the container and the network
function stop {
    # Check if the container is running
    local running
    check_docker_container
    running=$?
    echo "$running"
    if [ "$running" -ne '0' ]; then
        log "stop - Stopping the application with the docker compose down command. It means that the container and the network will be removed"
        if ! docker compose down; then
            log "stop - Failed to stop the docker container" "ERROR"
            return 1
        fi
    else
        log "stop - The container $DOCKER_CONTAINER_NAME is not running" $WARNING
    fi
}

# Usage: ./init.sh MQTT_USER MQTT_PASSWORD CERT_SUBJECT. Add a user to the MQTT server. Set the MQTT_USER, MQTT_PASSWORD and CERT_SUBJECT variables to the desired username, password and subject info.
function user_add_from_CLI {
    check_mounted_volumes
    # Check if the container is running
    log "user_add_from_CLI - Adding user $MQTT_USER to the MQTT server" $INFO
    local running
    check_docker_container
    running=$?
    if [ "$running" -eq '0' ]; then # if the container is not running exit
        exit 1
    fi
    
    local MQTT_USER=$1
    local MQTT_PASSWORD=$2
    local MQTT_SUBJECT=$3
    local MQTT_VALIDITY=$4

    # Control if the variables are set
    if [[ -z $MQTT_USER || -z $MQTT_PASSWORD || -z $MQTT_SUBJECT ]]; then
        log "user_add_from_CLI - The variables MQTT_USER, MQTT_PASSWORD and MQTT_SUBJECT must be set" $ERROR
        exit 1
    fi

    if_exist_user "$MQTT_USER"

    validate_dn "$MQTT_SUBJECT"
    if [ "$?" -eq '1' ]; then
        generate_client_certificates_CLI "$MQTT_USER" "$MQTT_PASSWORD" "$MQTT_SUBJECT" "$MQTT_VALIDITY"
        #set_permissions_and_ownership
        sleep 1
        restart
    else 
        log "user_add_from_CLI - The subject is not in the correct format" $ERROR
    fi
}

# Usage: ./init.sh <path/to/file.client>. Add user from a .client file with the format: summary;mqtt_user;mqtt_password[;validity].
function user_add_from_file {
    check_mounted_volumes
    # Check if the container is running
    local running
    check_docker_container
    running=$?
    if [ "$running" -eq '0' ]; then # if the container is not running exit
        log "user_add_from_file - The container $DOCKER_CONTAINER_NAME is not running" $ERROR
        exit 1
    fi

    local FILE_CLIENTS=$1
    # Cotrol if the variable is set and if the file exists
    if [[ -z $FILE_CLIENTS ]]; then
        log "user_add_from_file - The variable FILE_CLIENTS must be set" $ERROR
        exit 1
    fi
    if [[ ! -f $FILE_CLIENTS ]]; then
        log "user_add_from_file - The file $FILE_CLIENTS doesn't exist" $ERROR
        exit 1
    fi

    log "user_add_from_file - Adding users from file $FILE_CLIENTS to the MQTT server and creating certiciates"
    generate_client_certificates "$FILE_CLIENTS"
    #set_permissions_and_ownership
    sleep 1
    restart
}

# Usage: ./init.sh MQTT_USER. Delete a user from the MQTT server and all the certificates. Set the MQTT_USER variable to the username that want to be deleted. 
function user_del {
    # Check if the container is running
    check_mounted_volumes
    local running
    check_docker_container
    running=$?
    if [ "$running" -eq '0' ]; then # if the container is not running exit
        log "user_del - The container $DOCKER_CONTAINER_NAME is not running" $ERROR
        exit 1
    fi

    local MQTT_USER=$1
    # Control if the variable is set
    if [[ -z $MQTT_USER ]]; then
        log "user_del - The variable MQTT_USER must be set" $ERROR
        exit 1
    fi
    
    # Control if the user exists in the password file
    if ! grep -q "$MQTT_USER" "$MOUNTED_VOLUMES_TOP/mqtt/config/passwords.txt"; then
        log "user_del - User $MQTT_USER doesn't exist in the password file" $ERROR
        exit 1
    fi
    
    log "user_del - Deleting user $MQTT_USER from the MQTT server and all the certificates"
    sudo find mqtt/certs/clients/ -type d -name "$MQTT_USER" -exec rm -rf {} +
    docker run -it --rm -v "$(pwd)"/$MOUNTED_VOLUMES_TOP/mqtt/config:/mosquitto/config eclipse-mosquitto mosquitto_passwd -D /mosquitto/config/passwords.txt "$MQTT_USER"
    #set_permissions_and_ownership
    sleep 1
    restart
}

# Restart the MQTT broker
function restart {
    check_mounted_volumes
    local running
    check_docker_container
    running=$?
    if [ "$running" -ne '0' ]; then
        log "restart - Restarting the MQTT broker" $INFO
        docker container restart $DOCKER_CONTAINER_NAME
    else
        log "restart - The container $DOCKER_CONTAINER_NAME is not running" $ERROR
    fi
}

# Display the help message
function help {
    printf "This script is used to manage the MQTT broker with TLS. In the bottom there are all options needed to handle the application.\n Good Luck\n\n"
    awk 'BEGIN {print "Usage: <OPTION>\nOPTIONS:"} /^#/{comment=$0} /^function/ && $2 != "generate_client_certificates" && $2 != "generate_client_certificates_CLI" && $2 != "set_permissions_and_ownership" {printf "   %-30s %s\n", $2, substr(comment,1,181); if (length(comment) > 181) printf "%-35s %s\n", " ", substr(comment,182); comment=""}' init.sh
}

# =================Command line argument parsing to call functions based on input=================
case "$1" in
    init|clean|deep_clean|create_certs|clean_start|start|stop|user_add_from_CLI|user_add_from_file|user_del|restart)
        check_executables
        "$1" "$2" "$3" "$4"
        ;;
    help)
        help
        ;;
    *)
        echo "Invalid target: $1"
        help
        exit 1
        ;;
esac
