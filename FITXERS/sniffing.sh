#!/bin/bash

interface=wlp42s0
ip_broker=192.168.0.34

sudo tcpdump -i "$interface" -w capt.pcap &
tcpdump_pid=$!
trap 'sudo kill -9 $tcpdump_pid' EXIT

mosquitto_sub -h $ip_broker -t "#" -v > mqtt_sub.txt &
pid=$!
sleep 5
kill $pid
read topic msg < <(awk '{print $1, $2}' mqtt_sub.txt)
echo "Topic: $topic Msg: $msg \n"