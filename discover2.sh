#!/bin/bash

net=10.4.104.0
mask=/24
gw=10.4.104.1
interface=wlp42s0
num_clients=2
compose_file="./CLIENTS_ENV/docker-compose-offline.yml"

flag_mitm=false

while getopts "md" opt; do
    case $opt in 
        m) flag_mitm=true ;;
        d) flag_dos=true ;;
        \?) echo "opció invalida: -$OPTARG" >&2
            exit 1 ;;
    esac
done

cleanup() { #per apagar el docker amb Ctl+C
    echo -e "\n Tancant escenari:"
    sudo docker compose -f "$compose_file" down
    sudo docker stop escaner && sudo docker rm escaner

    #7- Analisis de la captura pcap amb zeek per extreure conclusions
    sudo docker run --rm --name analitzador --network host -v "$(pwd)/escaner":/home zeek/zeek bash -c "cd /home/zeek && zeek -r /home/zeek/capt.pcap"
    exit 0
}
trap cleanup SIGINT SIGTERM

mkdir -p ./escaner
sudo docker run -d --name escaner --network host -v "$(pwd)/escaner":/home ubuntu:latest sleep infinity #contenidor ubuntu mb interface del host
sudo docker exec escaner bash -c "apt update && apt install -y nmap masscan prips mosquitto-clients tcpdump"

#1- Masscan per trobar el broker
echo -e "\n    - Escaneig de xarxa per MQTT en el rang $net $mask : \n"
sudo docker exec escaner bash -c "cd /home && masscan $net$mask -p1883 --rate 1000 -oG masscan.txt" #masscan per trobar el broker via tcp port 1883
ip_broker=$(grep "Host: " ./escaner/masscan.txt | awk '{print $4}')

#2- Nmap -sn per trobar clients i script ips lliures
echo -e "\n IP Broker: $ip_broker \n    - Trobant IPs lliures pels clients mqtt \n" 
sudo docker exec escaner bash -c "cd /home && nmap -sn $net$mask -oG devices.txt && source /home/ip_lliures.sh $net$mask $num_clients" #llista de clients conectats i ip lliures a la xarxa 
source ./escaner/vars.env
ip_cl1=${ip_cl1} #no cal
ip_cl2=${ip_cl2}

#3- Nmap nse-script per trobar info rellevant del broker
echo -e "\n    - Subscribint al broker MQTT $ip_broker amb nmap... \n"
sudo docker exec escaner bash -c "cd /home && nmap -Pn --script mqtt-subscribe -p 1883 -oG info_broker.txt $ip_broker" #scipts info broker

#4- Sniffing mosquitto_sub per trobar tòpics
echo -e "\n    - Subscribint-se temporalment al broker per capturar missatges: \n"
sudo docker exec escaner bash -c "cd /home && timeout 5s mosquitto_sub -h $ip_broker -t '#' -v > mqtt_sub.txt" #escolta pasiva tòpics
read topic msg < <(awk '{print $1, $2}' ./escaner/mqtt_sub.txt)  #no cal printejar realment
echo -e "\n    - Topic: $topic  Msg: $msg \n"

#5- Captura de paquets amb tcpdump
sudo docker exec escaner bash -c "tcpdump -i $interface -w /home/zeek/capt.pcap &" #Monitoreig xarxa tcpdump

#6- Despegament d'entorn simulat

echo -e "\n    - Desplegant entorn simulat, executant analitzador i atac DDoS \n" #Desplegament d'escenari 
export ip_broker ip_cl1 ip_cl2 net gw interface mask
sudo -E docker compose -f "$compose_file" up -d

while true; do #per apagar el docker amb Ctl+C
    sleep 1
done     


#1- Masscan per trobar el broker
#2- Nmap -sn per trobar clients i script ips lliure
#3- Nmap nse-script per trobar info rellevant del broker
#4- Sniffing mosquitto_sub per trobar tòpics
#5- Captura de paquets amb tcpdump
#6- Despegament d'entorn simulat
#7- Analisis de la captura pcap amb zeek per extreure conclusions

