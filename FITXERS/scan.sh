#!/bin/bash
net=192.168.0.0
mask=/24


sudo masscan "$net$mask" -p1883 --rate 1000 -oG masscan.txt
ip_broker=$(grep "Host: " masscan.txt | awk '{print $4}')  #busquem al archiu "Host:" i d'aquella linea ens quedem el 4t arg. 
sudo nmap -sn $net$mask -oG devices.txt