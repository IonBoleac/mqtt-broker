# Docker container with MQTT
<table>
  <tr>
    <td><img src="../STICH.ico" alt="STICH"></td>
    <td>This is a docker container for running a normal MQTT broker. The MQTT broker is based on the <a href="https://mosquitto.org/">Eclipse Mosquitto</a> project.</td>
  </tr>
</table>


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
