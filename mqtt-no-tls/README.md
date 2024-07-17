# Docker container with MQTT
[![CC BY 4.0][cc-by-shield]][cc-by]
<table style="border-collapse: collapse; border: none;">
  <tr style="border: none;">
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


# License
This work is licensed under a
[Creative Commons Attribution 4.0 International License][cc-by].

[![CC BY 4.0][cc-by-image]][cc-by]

[cc-by]: http://creativecommons.org/licenses/by/4.0/
[cc-by-image]: https://i.creativecommons.org/l/by/4.0/88x31.png
[cc-by-shield]: https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg