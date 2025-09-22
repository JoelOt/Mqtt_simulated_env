#!/bin/bash
subred="${1}"
num_ips="${2}" #quant IPs
lista="devices.txt"

mapfile -t ocupadas < <(awk '/Status: Up/ { print $2 }' "$lista") #map IPs ocupades
declare -A ip_map 
for ip in "${ocupadas[@]}"; do
    ip_map["$ip"]=1
done

mapfile -t todas < <(prips "$subred") #IPs del rang

libres=() # Buscar IPs lliures desde la .100 (per evitar lios)
for ((i=100; i<${#todas[@]}; i++)); do
    ip="${todas[i]}"
    if [[ -z "${ip_map[$ip]}" ]]; then
        libres+=("$ip")
        if [[ ${#libres[@]} -ge "$num_ips" ]]; then  #sortir del bucle quan ja tenim el total
            break
        fi
    fi
done
: > /home/vars.env #guardar les ips en un fitxer per importar-les al codi principal
for ((i=0; i<${#libres[@]}; i++)); do
    echo "export ip_cl$((i+1))" = "${libres[i]}"
    echo "ip_cl$((i+1))"="${libres[i]}" >> /home/vars.env
done