# Docker container with MQTT
|  |  |
| --- | --- |
|![STICH](../STICH.ico) | This is a docker container for running a normal MQTT broker. The MQTT broker is based on the [Eclipse Mosquitto](https://mosquitto.org/) project.|

- The MQTT broker is running on the port 1883 and to access it isn't necessary any authentication and certificates.
- The MQTT broker is running on the port 51883 (due to the 1883 port is already used by the upon MQTT broker) and to access it is necessary the username and password.

## Starting
To run the container, you can use the following command that configure the environment with the necessary directory:

```bash
./init.sh
```

## Usage MQTT with zero authentication and zero certificates
To test the mqtt broker, run a subcriber with the following command:

```bash
mosquitto_sub -h localhost -t /test
```

After that, publish a message on the same topic with the following command:

```bash
mosquitto_pub -h localhost -t /test -m "Hello, World!"
```

You should see the message "Hello, World!" on the subscriber terminal.

## Usage MQTT with only authentication 
To test the mqtt broker with authentication, use the following command to publish a message:

```bash
mosquitto_pub -h localhost -p 51883 -t /test -m "Hello, World!" -u user -P password
```

And to subscribe to the topic, use the following command:

```bash
mosquitto_sub -h localhost -p 51883 -t /test -u user -P password
```

You should see the message "Hello, World!" on the subscriber terminal.

### Add new client to the MQTT broker
To add a new client to the broker MQTT, run the following command:

```bash
docker run -it --rm -v "$(pwd)"/mounted_volumes/mqtt-with-auth/config:/mosquitto/config eclipse-mosquitto mosquitto_passwd -b /mosquitto/config/passwords.txt username password
```

Where `username` is the username of the new client wiht `password` as the password of the new client.

After that, restart the MQTT broker with the following command:

```bash
docker restart mqtt-with-auth
```
