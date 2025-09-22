#!/bin/bash
net=192.168.0.0   #requeriments: nmap, masscan, prips, docker, mosquitto-clients, tcpdump, 
mask=/24
interface=wlp42s0
num_clients=2
compose_file="docker-compose-offline.yml"

cleanup() { #per apagar el docker amb Ctl+C
    echo -e "\n[!] Tancant escenari:"
    if [ -n "$tcpdump_pid" ]; then
        echo "Deteniendo tcpdump (PID: $tcpdump_pid)..."
        sudo kill -SIGTERM "$tcpdump_pid"
    fi
    sudo docker compose -f "$compose_file" down
    exit 0
}
trap cleanup SIGINT SIGTERM


# 1- Network Reconnaissance:
echo "escaneig de xarxa per MQTT en el rang $net $mask : \n"

sudo masscan "$net$mask" -p1883 --rate 1000 -oG masscan.txt
ip_broker=$(grep "Host: " masscan.txt | awk '{print $4}')  #busquem al archiu "Host:" i d'aquella linea ens quedem el 4t arg. 
sudo nmap -sn $net$mask -oG devices.txt

#assignació d'ip:
echo "Trobant IPs lliures pels clients mqtt"
source ip_lliures.sh $net$mask $num_clients

#2- descobriment de tòpics: Ens subscribim a # (qualsevol tòpic) i analitzem els msg MQTT que arriben i el seu tòpic. 
echo "Subscribint al broker MQTT $ip_broker: "
sudo nmap -Pn --script mqtt-subscribe -p 1883 -oG info_broker.txt $ip_broker

mosquitto_sub -h $ip_broker -t "#" -v > mqtt_sub.txt &
pid=$!
sleep 5
kill $pid
read topic msg < <(awk '{print $1, $2}' mqtt_sub.txt)
echo "Topic: $topic Msg: $msg \n"


# 3- Captura de trànsit
sudo tcpdump -i $interface -w capt.pcap &
tcpdump_pid=$!


#4- Desplegament d'escenari
echo "Desplegant entorn simulat, executant analitzador i atac DDoS \n"
export ip_broker
sudo -E docker compose -f "$compose_file" up -d

#5- passar-ho a zeek per analitzar els resultats

while true; do #per apagar el docker amb Ctl+C
    sleep 1
done


#1- Crear contenidor escaner: 
    #escaneja i eso
#2- Contenidor escolta (1- mosquitto 2-tcpdump)
#3- Desplegament: