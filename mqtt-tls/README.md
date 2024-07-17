# Run a MQTT Brocker over TLS
[![CC BY 4.0][cc-by-shield]][cc-by]
<table style="border-collapse: collapse; border: none;">
  <tr style="border: none;">
    <td><img src="../STICH.ico" alt="STICH"></td>
    <td>In this directory there is a script that allows to run a MQTT Brocker over TLS in a Docker container. The script is written in bash and it's possible to manage the broker by using the script.</a> project.</td>
  </tr>
</table>


## Folder Structure
```
.
├── README.md              # Project documentation
├── init.sh                # Bash script to handle the MQTT Broker
├── init.py                # Python script to handle the MQTT Broker. The same with the above bash script (is under development)
├── docker-compose.yaml    # Docker Compose configuration
└── mqtt
    ├── certs
    │   ├── brokers        # Certificates data for the MQTT Broker
    │   │   └── ...        # Specific broker certificates
    │   ├── ca             # CA certificate and key
    │   │   └── ...        # CA specific files
    │   ├── clients        # Certificates data for all the clients
    │   │   └── ...        # Additional client certificates
    ├── mosquitto.conf      # MQTT Broker configuration
    └── README.md           # Documentation explaining the certificates
```

# Possibile options
The script `init.sh` has the following options:

```bash
./init.sh <Option>
```

| Option | Description |
| --- | --- |
| [init](#init-the-environment)                                 | Initialize the environment|
| [clean](#clean-the-application)                               | Clean only the mounted volumes without removing the certificates|
| [deep_clean](#clean-the-application)                          | Deep clean the application removing all the certificates and the mounted volumes|
| [create_certs](#create-the-certificates)                      | Create the certificates for the MQTT broker, the CA and the existed clients|
| [clean_start](#start-the-application)                         | Start the application with a clean start that cleans the mounted volumes, initializes the environment, creates the certificates and starts the application|
| [start](#start-the-application)                               | Start the application only with the docker compose up command. The certificates must be created before.|
| [stop](#clean-the-application)                                | Stop the application with the docker compose down command that remove the container and the network|
| [user_add_from_CLI](#add-a-new-client-from-the-command-line)  | Usage: ./init.sh MQTT_USER MQTT_PASSWORD CERT_SUBJECT. Add a user to the MQTT server. Set the MQTT_USER, MQTT_PASSWORD and CERT_SUBJECT variables to the desired username, password and subject info.|
| [user_add_from_file](#create-a-new-client-from-a-file)        | Usage: ./init.sh <path/to/file.client>. Add user from a .client file with the format: summary;mqtt_user;mqtt_password[;validity].|
| [user_del](#remove-a-client)                                  | Usage: ./init.sh MQTT_USER. Delete a user from the MQTT server and all the certificates. Set the MQTT_USER variable to the username that want to be deleted.|
| [restart](#restart-the-application)                           | Restart the MQTT broker|
| [help](#help)                                                 | Display the help message|

## Help
It's possible to manage and have more control over the application by using the other possible options of the `init.sh` script. To see all the available options, run the following command:

```bash
./init.sh help
```

The output will show all the available options to manage the application.

## Init the environment
To initialize the environment, run the following command:

```bash
./init.sh init
```

This command will create the necessary directories to run the application. 

## Create the certificates
To create the certificates for the MQTT Brocker, the CA and the clients, run the following command:

```bash
./init.sh create_certs
```

This command will create the certificates for the MQTT Brocker, the CA and the clients. The certificates will be saved in the directory `mqtt/certs/`. The certificates for the MQTT Brocker will be saved in the directory `mqtt/certs/brokers/`, the CA certificates will be saved in the directory `mqtt/certs/ca/` and the client certificates will be saved in the directory `mqtt/certs/clients/`.

## Start the application
To semplify the process of running a MQTT Brocker over TLS, is used the docker image `eclipse-mosquitto:2.0-openssl` that is a MQTT Brocker. The image is available on the Docker Hub at the following link: [eclipse-mosquitto](https://hub.docker.com/_/eclipse-mosquitto). To start the application, it's necessary to have Docker installed on the machine. If it dosen't have Docker installed, it's possible download the application from the official website: [Docker](https://www.docker.com/). After installing Docker, run the following command to start the MQTT Brocker over TLS:

```bash
./init.sh clean_start
```

This command will initialize the environment, create the certificates for the MQTT Brocker, the CA and the clients, and start the application.

If it's necessary to start the application without cleaning the mounted volumes, run the following command:

```bash
./init.sh start
```

In the script there are some variables that must be set with the own data for the TLS certificate.

The script will create a container with the MQTT Brocker and the necessary configuration to run the application. The MQTT Brocker will be available on the port `8883` and the TLS certificate will be available on the path [./mqtt/certs/](./mqtt/certs/). The script will also create a network to connect the container with the MQTT Brocker and the client.

## Create a new client from a file 
The `init.sh` when started it self generate all the necessaries certificates and authentication data to run a client from the `.client`files. Infact if necessary it's possible to generate a new client at the moment of starting of the application. It's just need to add a `*.client` file in the directory `mqtt/certs/clients/` and where `*` is the unique name of the client. And  In this repo there are two clients just for example as can be seen in the following path [`mqtt/certs/clients/`](./mqtt/certs/clients/). In case of necessity to generate a neew client once the container is started, run the following command:

```bash
./init.sh user_add_from_file <FILE_CLIENT>
```

Where `<FILE_CLIENT>` is the path of the file that contains the client data. The file must be in the format of the `.client` file. The script will generate the necessary certificates, in the same directory of the client file, and authentication all the data to run the client. The contents of the client file must be in the following format:

```config
/C=IT/ST=Italy/L=Italy/O=Example/OU=Client/CN=email@example.com;example;Secure[;100]
```

Where the values are separated by the character `;`. The fields are the following: 
- First field are the data necessary to generate the client certificate
- Second field is the username of the client
- Third field is the password of the client
- Fourth field is the validity period of the client certificate in days. This field is optional and the default value is 365 days.

PS. Save the `.client` file with the same name of the username of the client. This is necessary to the script to delete the client data when a client is removed. 

### Example of adding a new client from a file
To add a new client from a file, run the following command that use a file `add.client` that is available in the main directory like example:

```bash
./init.sh user_add_from_file add.client
```

The script will generate the necessary certificates and authentication all the data to run the client. 

All certificates and data of the client will be saved in the directory `mqtt/certs/clients/` and the certificates will be available in the directory `mqtt/certs/clients/<USERNAME>/`.

## Add a new client from the command line
To add a new client to the MQTT Brocker, run the following command:

```bash
./init.sh user_add_from_CLI <USERNAME> <PASSWORD> <SUBJECTS> [<VALIDITY>]
```

Where `<USERNAME>` is the username of the client, `<PASSWORD>` is the password of the client, `<SUBJECTS>` are the info necessary for certificates.  The fouth variable is an optional. This is used to set a validation time in days for the user's certificates. Default is set to 365 days. The script will generate the necessary certificates and authentication all the data to run the client. 

## Remove a client
To remove a client from the MQTT Brocker, run the following command:

```bash
./init.sh user_del <USERNAME>
```

Where `<USERNAME>` is the username of the client. The script will remove all the data of the client.


## Test the application
To test the application, it's possible to use the client `mosquitto_sub` that is available thanks the apt package `mosquitto_clients`. To start the client, run the following command:

```bash
mosquitto_sub -h localhost -p 8883 -u example_user -P 'insecure' --cafile mqtt/certs/ca/ca.crt --cert mqtt/certs/clients/example_user/example_user.crt --key mqtt/certs/clients/example_user/example_user.key -t /world
```

Through this command is created a subcriber that listen on the topic `/world` and print the messages that are published on this topic. To publish a message on the topic `/world`, run the following command:

```bash
mosquitto_pub -h localhost -p 8883 -u example_user -P 'insecure' --cafile mqtt/certs/ca/ca.crt --cert mqtt/certs/clients/example_user/example_user.crt --key mqtt/certs/clients/example_user/example_user.key -m hello -t /world
```

Or try to publish a message with the client `example_user1` that is available in the directory `mqtt/certs/clients/example_user1/`:

```bash
mosquitto_pub -h localhost -p 8883 -u example_user1 -P 'Secure' --cafile mqtt/certs/ca/ca.crt --cert mqtt/certs/clients/example_user1/example_user1.crt --key mqtt/certs/clients/example_user1/example_user1.key -m hello -t /world
```

## Restart the application
To restart the application, run the following command:

```bash
./init.sh restart
```


## Clean the application
To clean all data that are created by the script including all the crestifications, run the following command:

```bash
./init.sh deep_clean
```

If it's necessary to clean only the `mounted_volumes`, run the following command:

```bash
./init.sh clean
```

If it's necessary to clean only the container and the network, run the following command that run `docker compose down`:

```bash
./init.sh stop
```
This command will remove the container and the network but the certificates and the client data will be saved.

## Logging system
The script has a logging system that saves all the logs in the file `data-log.log`. The log file is saved in the [logs](./logs/) directory. The log file is useful to understand what the script does and to debug the script in case of errors. The format of the log file is the following:

```log
2024-06-30 15:00:00 - INFO - init.sh - start - The script has started
time - log_level - file - function - message
```


# License
This work is licensed under a
[Creative Commons Attribution 4.0 International License][cc-by].

[![CC BY 4.0][cc-by-image]][cc-by]

[cc-by]: http://creativecommons.org/licenses/by/4.0/
[cc-by-image]: https://i.creativecommons.org/l/by/4.0/88x31.png
[cc-by-shield]: https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg