#!/bin/bash
subred="${1}"
num_ips="${2}" # Quantitat d'IPs necessàries

lista= echo "" > ips.txt # Ara llegim directament el fitxer amb IPs actives

mapfile -t ocupadas < "$lista"
declare -A ip_map 
for ip in "${ocupadas[@]}"; do
    ip_map["$ip"]=1
done
mapfile -t todas < <(prips "$subred") # Generem totes les IPs del rang
libres=()
# Busquem IPs lliures començant des de .100
for ((i=200; i<${#todas[@]}; i++)); do
    ip="${todas[i]}"
    if [[ -z "${ip_map[$ip]}" ]]; then
        libres+=("$ip")
        if [[ ${#libres[@]} -ge "$num_ips" ]]; then
            break
        fi
    fi
done
: > /home/vars.env # Netegem el fitxer abans d'escriure
for ((i=0; i<${#libres[@]}; i++)); do
    echo "ip_cl$((i+1))=\"${libres[i]}\"" >> /home/vars.env
done

# Mostrem resultats (opcional)
echo "IPs lliures trobades:"
printf '%s\n' "${libres[@]}"