from mitmproxy import tcp

def tcp_message(flow: tcp.TCPFlow):
    data = flow.messages[-1].content
    try:
        if b"test" and not flow.messages[-1].from_client in data:
            print("[+] Mensaje original:", data)
            data_mod = data.replace(b'"test":1', b'"test":5')
            flow.messages[-1].content = data_mod
            print("[+] Mensaje modificado:", data_mod)
    except Exception as e:
        print("[!] Error procesando mensaje:", e)


#llisteta dels hooks de mitmproxy:
#https://docs.mitmproxy.org/stable/addons/event-hooks/