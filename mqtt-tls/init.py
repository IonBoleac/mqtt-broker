# same file as init.sh but in python
# The script is under development and it is not yet fully functional

import os
import subprocess
import sys
import re
from datetime import datetime

# Set verbosity
V = 1
Q_STDOUT = "> /dev/null"
Q_STDERR = "2> /dev/null"

if V != 0:
    Q_STDOUT = ""
    Q_STDERR = "2>> error.log"

# =================Logging=================
WARNING = "Warning"
ERROR = "Error"
INFO = "Info"
LOG_DIR = "./logs"
LOG_TIME = datetime.now().strftime("%Y-%m-%d")
os.makedirs(LOG_DIR, exist_ok=True)
LOG_FILE = os.path.join(LOG_DIR, f"{LOG_TIME}_log.txt")

def log(message, level=INFO):
    print(f"{level}: {message}")
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_FILE, "a") as log_file:
        log_file.write(f"{timestamp} - {level} - {message}\n")
    log_file.close()

# =================Variable Definitions=================
GIT_VERSION = subprocess.getoutput("git describe --abbrev=6 --dirty --always --tags")
MOUNTED_VOLUMES_TOP = "mounted_volumes"

DOCKER_CONTAINER_NAME = "mqtt-tls"

# Data for the certs
IP_BROKER = "localhost"
ORGANIZATION_NAME = "mechlav.com"
SUBJECT_ROOT_CA = f"/C=IT/ST=Italy/L=Italy/O={ORGANIZATION_NAME}/OU=CA/CN={ORGANIZATION_NAME}"
SUBJECT_SERVER = f"/C=IT/ST=Italy/L=Italy/O={ORGANIZATION_NAME}/OU=Broker/CN={IP_BROKER}"

# BROKER certificates
BROKER_KEY = "mqtt/certs/broker/broker.key"
BROKER_CSR = "mqtt/certs/broker/broker.csr"
BROKER_CRT = "mqtt/certs/broker/broker.crt"

# CA certificates
CA_KEY = "mqtt/certs/ca/ca.key"
CA_CRT = "mqtt/certs/ca/ca.crt"

# Check for required executables
EXECUTABLES = ["nohup", "git", "docker", "openssl"]
for exec in EXECUTABLES:
    if subprocess.call(f"which {exec}", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE) != 0:
        print(f"No {exec} in PATH")
        sys.exit(1)

def check_docker():
    if int(subprocess.getoutput(F"docker container ps | grep -c {DOCKER_CONTAINER_NAME}")) == 0:
        log(f"Docker container {DOCKER_CONTAINER_NAME} is not running", WARNING)
        sys.exit(1)

def validate_dn(dn):
    pattern = r"^/C=[A-Z]{2}/ST=[^/]+/L=[^/]+/O=[^/]+/OU=[^/]+/CN=[^/]+$"
    if re.match(pattern, dn):
        print("Valid DN")
    else:
        print("\nInvalid DN\nInvalid DN: ", dn)
        sys.exit(1)

def if_exist_user(mqtt_user):
    return 
    password_file = os.path.join(MOUNTED_VOLUMES_TOP, "mqtt/config/passwords.txt")
    with open(password_file, "r") as file:
        if mqtt_user in file.read():
            print(f"User {mqtt_user} already exists in the password file")
            log(WARNING, f"User {mqtt_user} already exists in the password file")
            sys.exit(1)

def set_permissions_and_ownership():
    password_file = os.path.join(MOUNTED_VOLUMES_TOP, "mqtt/config/passwords.txt")
    #os.chmod(password_file, 0o700)
    #os.chown(password_file, 0, 0)

# =================DEFINE OPTIONS AS FUNCTIONS=================
# Initialize the environment
def init():
    print("Initializing the environment creating the directories and copying the configuration files needed for MQTT broker")
    os.makedirs(os.path.join(MOUNTED_VOLUMES_TOP, "mqtt/config/certs"), exist_ok=True)
    os.makedirs(os.path.join(MOUNTED_VOLUMES_TOP, "mqtt/data"), exist_ok=True)
    if not os.path.isfile(os.path.join(MOUNTED_VOLUMES_TOP, "mqtt/config/mosquitto.conf")):
        subprocess.call(f"cp mqtt/mosquitto.conf {MOUNTED_VOLUMES_TOP}/mqtt/config/mosquitto.conf", shell=True)
    if not os.path.isfile(os.path.join(MOUNTED_VOLUMES_TOP, "mqtt/config/passwords.txt")):
        open(os.path.join(MOUNTED_VOLUMES_TOP, "mqtt/config/passwords.txt"), 'a').close()
    set_permissions_and_ownership()

# Clean only the mounted volumes without removing the certificates
def clean():
    log("Removing the mounted_volumes directories.", INFO)
    subprocess.call(f"sudo rm -rf {MOUNTED_VOLUMES_TOP}", shell=True)

# Deep clean the application removing all the certificates and the mounted volumes
def deep_clean():
    log("Deep cleaning the application removing all the certificates and the mounted volumes within stopping the application.", INFO)
    stop()
    subprocess.call(f"sudo rm -rf {MOUNTED_VOLUMES_TOP}", shell=True)
    subprocess.call(f"sudo find mqtt/certs/ca/ -type f \\( -name '*.crt' -o -name '*.key' -o -name '*.srl' \\) -exec rm -f {{}} +", shell=True)
    subprocess.call(f"sudo find mqtt/certs/broker/ -type f \\( -name '*.crt' -o -name '*.key' -o -name '*.csr' \\) -exec rm -f {{}} +", shell=True)
    subprocess.call(f"sudo find mqtt/certs/clients/ -type f \\( -name '*.crt' -o -name '*.key' -o -name '*.csr' \\) -exec rm -f {{}} +", shell=True)
    subprocess.call(f"sudo find mqtt/certs/clients/ -mindepth 1 -type d -exec rm -rf {{}} +", shell=True)

# Create all the certificates: CA and the certificates for the MQTT clients
def generate_client_certificates(client_file):
    log(f"Creating client certificate for {client_file}", INFO)

    if not os.path.isfile(CA_CRT) or not os.path.isfile(CA_KEY) or not os.path.isfile(os.path.join(MOUNTED_VOLUMES_TOP, "mqtt/config/passwords.txt")):
        print("Required files are missing. There are missing files for the CA certificate and the passwords.txt file.")
        sys.exit(1)

    with open(client_file, 'r') as file:
        data = file.readline().strip().split(';')
        if len(data) < 3:
            print("The client file is not in the correct format. The format must be: summary;mqtt_user;mqtt_password")
            sys.exit(1)
        summary, mqtt_user, mqtt_password = data[:3]
        validity = int(data[3]) if len(data) > 3 else 365

    if_exist_user(mqtt_user)
    os.makedirs(f"mqtt/certs/clients/{mqtt_user}", exist_ok=True)
    base_name = f"mqtt/certs/clients/{mqtt_user}/{mqtt_user}"

    subprocess.call(f"openssl genrsa -out {base_name}.key", shell=True)
    subprocess.call(f"openssl req -new -key {base_name}.key -out {base_name}.csr -subj '{summary}'", shell=True)
    subprocess.call(f"openssl x509 -req -CA {CA_CRT} -CAkey {CA_KEY} -CAcreateserial -in {base_name}.csr -out {base_name}.crt -days {validity}", shell=True)
    subprocess.call(f"docker run -it --rm -v $(pwd)/{MOUNTED_VOLUMES_TOP}/mqtt/config:/mosquitto/config eclipse-mosquitto mosquitto_passwd -b /mosquitto/config/passwords.txt {mqtt_user} {mqtt_password}", shell=True)

# Create the certificates for the MQTT clients from the command line in the forma: username password subject
def generate_client_certificates_CLI(client, client_password, client_subject, validity=365):
    validity = int(validity)
    client_path = f"mqtt/certs/clients/{client}/{client}"

    if_exist_user(client)
    os.makedirs(f"mqtt/certs/clients/{client}", exist_ok=True)

    subprocess.call(f"openssl genrsa -out {client_path}.key", shell=True)
    subprocess.call(f"openssl req -new -key {client_path}.key -out {client_path}.csr -subj '{client_subject}'", shell=True)
    subprocess.call(f"openssl x509 -req -CA {CA_CRT} -CAkey {CA_KEY} -CAcreateserial -in {client_path}.csr -out {client_path}.crt -days {validity}", shell=True)
    subprocess.call(f"docker run -it --rm -v $(pwd)/{MOUNTED_VOLUMES_TOP}/mqtt/config:/mosquitto/config eclipse-mosquitto mosquitto_passwd -b /mosquitto/config/passwords.txt {client} {client_password}", shell=True)

# Create the certificates for the MQTT broker, the CA and the existed clients
def create_certs():
    print("===Creating CA certificate===")
    subprocess.call(f"openssl genrsa -out {CA_KEY} 4096", shell=True)
    subprocess.call(f"openssl req -x509 -new -nodes -key {CA_KEY} -sha256 -days 1024 -out {CA_CRT} -subj '{SUBJECT_ROOT_CA}'", shell=True)

    print("===Creating BROKER certificate===")
    subprocess.call(f"openssl genrsa -out {BROKER_KEY} 2048", shell=True)
    subprocess.call(f"openssl req -new -key {BROKER_KEY} -out {BROKER_CSR} -subj '{SUBJECT_SERVER}'", shell=True)
    subprocess.call(f"openssl x509 -req -in {BROKER_CSR} -CA {CA_CRT} -CAkey {CA_KEY} -CAcreateserial -out {BROKER_CRT} -days 500 -sha256", shell=True)

    print("===Creating CLIENT certificate===")
    client_files = [f for f in os.listdir('mqtt/certs/clients') if f.endswith('.client')]
    print(f"There are {len(client_files)} clients to create")
    for client_file in client_files:
        generate_client_certificates(f"mqtt/certs/clients/{client_file}")

    print(f"Copying the certificates to the {MOUNTED_VOLUMES_TOP}")
    subprocess.call(f"sudo cp -f {CA_CRT} {MOUNTED_VOLUMES_TOP}/mqtt/config/certs/ca.crt", shell=True)
    subprocess.call(f"sudo cp -f {BROKER_CRT} {MOUNTED_VOLUMES_TOP}/mqtt/config/certs/broker.crt", shell=True)
    subprocess.call(f"sudo cp -f {BROKER_KEY} {MOUNTED_VOLUMES_TOP}/mqtt/config/certs/broker.key", shell=True)

# Start the application with a clean start that cleans the mounted volumes, initializes the environment, creates the certificates and starts the application
def clean_start():
    print("Starting the application with a clean start. Cleaning the mounted volumes, initializing the environment, creating the certificates and starting the application")
    running = int(subprocess.getoutput(F"docker container ps | grep -c {DOCKER_CONTAINER_NAME}"))
    print(f"Running: {running}")
    if running == 0:
        deep_clean()
        init()
        create_certs()
        subprocess.Popen("nohup docker compose up -d &", shell=True)
        print(f"Application Started - VERSION {GIT_VERSION}")
    else:
        print("Already running")
        subprocess.call("docker compose ps", shell=True)
        sys.exit(1)

# Start the application only with the docker compose up command. The certificates must be created before.
def start():
    print("Starting the application with only the docker compose up command. The certificates must be created before")
    running = int(subprocess.getoutput(F"docker container ps | grep -c {DOCKER_CONTAINER_NAME}"))
    print(f"Running: {running}")
    if running == 0:
        subprocess.Popen("nohup docker compose up -d &", shell=True)
        print(f"Application Started - VERSION {GIT_VERSION}")
    else:
        print("Already running")
        subprocess.call("docker compose ps", shell=True)
        sys.exit(1)

# Stop the application with the docker compose down command that remove the container and the network
def stop():
    print("Stopping the application with the docker compose down command")
    subprocess.call("docker compose down", shell=True)

# Usage: ./init.sh MQTT_USER MQTT_PASSWORD CERT_SUBJECT. Add a user to the MQTT server. Set the MQTT_USER, MQTT_PASSWORD and CERT_SUBJECT variables to the desired username, password and subject info.
def user_add_from_CLI(mqtt_user, mqtt_password, mqtt_subject, mqtt_validity):
    if_exist_user(mqtt_user)
    print(f"Adding user {mqtt_user} to the MQTT server")
    validate_dn(mqtt_subject)
    generate_client_certificates_CLI(mqtt_user, mqtt_password, mqtt_subject, mqtt_validity)
    subprocess.call("sleep 1", shell=True)
    restart()

# Usage: ./init.sh <path/to/file.client>. Add user from a .client file with the format: summary;mqtt_user;mqtt_password[;validity].
def user_add_from_file(file_clients):
    print(f"Adding users from file {file_clients} to the MQTT server and creating certificates")
    generate_client_certificates(file_clients)
    subprocess.call("sleep 1", shell=True)
    restart()

# Usage: ./init.sh MQTT_USER. Delete a user from the MQTT server and all the certificates. Set the MQTT_USER variable to the username that want to be deleted. 
def user_del(mqtt_user):
    print(f"Deleting user {mqtt_user} from the MQTT server. Remember to restart the broker")
    subprocess.call(f"sudo find mqtt/certs/clients/ -type d -name '{mqtt_user}' -exec rm -rf {{}} +", shell=True)
    subprocess.call(f"docker run -it --rm -v $(pwd)/{MOUNTED_VOLUMES_TOP}/mqtt/config:/mosquitto/config eclipse-mosquitto mosquitto_passwd -D /mosquitto/config/passwords.txt {mqtt_user}", shell=True)
    subprocess.call("sleep 1", shell=True)
    restart()

# Restart the MQTT broker
def restart():
    check_docker()
    try:
        log("Restarting the MQTT broker", INFO)
        with open(LOG_FILE, "a") as log_file:
            subprocess.call(f"docker container restart {DOCKER_CONTAINER_NAME}", shell=True, stdout=log_file, stderr=log_file, text=True)
        #docker.from_env().containers.get(DOCKER_CONTAINER_NAME).restart()
        log_file.close()
    except Exception as e:
        log(f"Error to run subprocess call.", ERROR)

# Display the help message
def help():
    subprocess.call(f"awk 'BEGIN {{print \"Usage: <OPTION>\\nOPTIONS:\"}} /^#/{{comment=$0}} /^def/ && $2 != \"generate_client_certificates\" && $2 != \"generate_client_certificates_CLI\" && $2 != \"set_permissions_and_ownership\" {{printf \"   %-30s %s\\n\", $2, substr(comment,1,181); if (length(comment) > 181) printf \"%-35s %s\\n\", \" \", substr(comment,182); comment=\"\"}}' init.py", shell=True)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Invalid target")
        help()
        sys.exit(1)

    target = sys.argv[1]
    args = sys.argv[2:]

    functions = {
        'init': init,
        'clean': clean,
        'deep_clean': deep_clean,
        'create_certs': create_certs,
        'clean_start': clean_start,
        'start': start,
        'stop': stop,
        'user_add_from_CLI': lambda: user_add_from_CLI(*args),
        'user_add_from_file': lambda: user_add_from_file(*args),
        'user_del': lambda: user_del(*args),
        'restart': restart,
        'help': help
    }

    if target in functions:
        functions[target]()
    else:
        print("Invalid target:", target)
        help()
        sys.exit(1)

