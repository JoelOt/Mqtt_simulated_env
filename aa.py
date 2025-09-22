from mitmproxy import tcp

def tcp_message(flow: tcp.TCPFlow):
    data = flow.messages[-1].content
    try:
        if not flow.messages[-1].from_client:
            # Verificar si el mensaje es de tipo PUBLISH MQTT (primer byte en el rango de 0x30-0x3F)
            # El byte de tipo de mensaje MQTT para PUBLISH está entre 0x30 (48) y 0x3F (63)
            if len(data) > 0 and 0x30 <= data[0] <= 0x3F:
                print("[+] Mensaje MQTT PUBLISH detectado.")
                
                # Aquí puedes modificar el campo 'payload' (los datos del mensaje MQTT)
                # Si el mensaje es un PUBLISH, modificamos el contenido.
                # Asumimos que el payload es lo que sigue después del encabezado fijo de MQTT (donde comienza el contenido real).
                
                # Puedes modificar el payload aquí. En este caso reemplazamos el contenido completo por "MODIFICADO"
                # Nota: Este ejemplo reemplaza todo el mensaje con "MODIFICADO", pero puedes modificar solo el contenido del payload si lo necesitas.
                data_mod = data[:2] + b"MODIFICADO"  # Solo un ejemplo, puedes modificar la lógica aquí.
                
                # Reemplazar el contenido del mensaje con el mensaje modificado
                flow.messages[-1].content = data_mod
                print("[+] Mensaje modificado:", data_mod)
    except Exception as e:
        print("[!] Error procesando mensaje:", e)

