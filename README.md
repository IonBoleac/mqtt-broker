# MQTT Broker with and without TLS
[![CC BY 4.0][cc-by-shield]][cc-by]
![MQTT Broker](STICH.jpeg)

In this repo are some examples of running the MQTT Broker with and without TLS in a Linux-based OS. The MQTT Broker is the Mosquitto Broker. The examples are in two directories: `mqtt-tls` and `mqtt-no-tls`. The `mqtt-tls` directory contains the files necessary to run the MQTT Broker with TLS. The `mqtt-no-tls` directory contains the files necessary to run the MQTT Broker without TLS. This last directory is useful to run the MQTT Broker with and without authentication.

| **File** | **Description** |
| --- | --- |
| **[/mqtt-tls/README.md](./mqtt-tls/README.md)** | File that contains the instructions to run the MQTT Broker over TLS |
| **[/mqtt-no-tls/README.md](./mqtt-no-tls/README.md)** | File that contains the instructions to run the MQTT Broker without TLS |


## Simplified Instructions Usage
Run the following command to clone the repository:

```bash
git clone https://github.com/IonBoleac/mqtt-broker.git
```

After cloning the repository, go to the `mqtt-tls` or `mqtt-no-tls` directory and follow the instructions in the respectively `README.md` file. Otherwise, you can run the following script:

```bash
./run_app.sh
```

Using the bellow script, you may run interactively the prefered MQTT Broker. The script will ask you to choose between the MQTT Broker with or without TLS. After choosing, the script will run the MQTT Broker in a Docker container.


# License
This work is licensed under a
[Creative Commons Attribution 4.0 International License][cc-by].

[![CC BY 4.0][cc-by-image]][cc-by]

[cc-by]: http://creativecommons.org/licenses/by/4.0/
[cc-by-image]: https://i.creativecommons.org/l/by/4.0/88x31.png
[cc-by-shield]: https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg
