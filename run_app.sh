#!/bin/bash
source ./mqtt-no-tls/init.sh

main_directory=$(pwd)

logo (){
    echo ""
    echo "###################################################################"
    echo "#                                                                 #"
    echo -e "#     \033[34m███╗   ███╗\033[0m   \033[32m████╗\033[0m  \033[34m████████╗\033[0m\033[32m████████╗\033[0m                     #"
    echo -e "#     \033[34m████╗ ████║\033[0m \033[32m██╔═══██╗\033[0m\033[34m╚══██╔══╝\033[0m\033[32m╚══██╔══╝\033[0m                     #"
    echo -e "#     \033[32m██╔████╔██║\033[0m \033[34m██║   ██║\033[0m   \033[32m██║\033[0m      \033[34m██║\033[0m                        #"
    echo -e "#     \033[34m██║╚██╔╝██║\033[0m \033[32m██║   ██║\033[0m   \033[34m██║\033[0m      \033[32m██║\033[0m                        #"
    echo -e "#     \033[32m██║ ╚═╝ ██║\033[0m \033[34m╚██████╔╝\033[0m   \033[32m██║\033[0m      \033[34m██║\033[0m                        #"
    echo -e "#     \033[34m╚═╝     ╚═╝\033[0m  \033[32m╚═════╝ \033[0m   \033[34m╚═╝\033[0m      \033[32m╚═╝\033[0m                        #"
    echo "#                                                                 #"
    echo "#  ┌───────────────────────────────────────────────────────┐      #"
    echo "#  │ MQTT Broker Manager                                   │      #"
    echo "#  │  - Deployed with Docker                               │      #"
    echo "#  │  - Modes:                                             │      #"
    echo "#  │      ✔ TLS (Encrypted Secure Communication)           │      #"
    echo "#  │      ✔ Auth (Username/Password)                       │      #"
    echo "#  │      ✔ Open (No TLS/Auth)                             │      #"
    echo "#  └───────────────────────────────────────────────────────┘      #"
    echo "#                                                                 #"
    echo "#  Powered by MQTT and Docker                                     #"
    echo "###################################################################"
    echo ""
    # Press enter to continue
    echo -n "Press Enter to continue"
    read
}



# Run the MQTT Broker Manager

# Print the logo
logo

# Ask the user to select the mode
echo "Select the mode to run the MQTT Broker Manager"
echo "1. TLS (Encrypted Secure Communication)"
echo "2. Auth (Username/Password)"
echo "3. Open (No TLS/Auth)"
echo "4. Exit"
echo ""
echo -n "Enter the mode number: "
read mode

# Check the mode
if [ $mode -eq 1 ]
then
    echo "Running the MQTT Broker Manager in TLS mode"
    echo ""
    cd mqtt-tls/
    echo "###################"
    ./init.sh help
    echo "###################"
    echo ""
    echo "Chose the option to run the MQTT Broker Manager in TLS mode"
    echo ""
    read -p "Enter the option: " option
    ./init.sh $option
elif [ $mode -eq 2 ]
then
    echo "Running the MQTT Broker Manager in Auth mode"
    cd mqtt-no-tls
    
    start_mqtt_with_auth
    
elif [ $mode -eq 3 ]
then
    echo "Running the MQTT Broker Manager in Open mode"
    cd mqtt-no-tls
    start_mqtt_no_auth
elif [ $mode -eq 4 ]
then
    echo "Exiting the MQTT Broker Manager"
    exit 0
else
    echo "Invalid mode number. Exiting the MQTT Broker Manager"
    exit 1
fi
