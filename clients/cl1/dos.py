import paho.mqtt.client as mqtt
import time
from threading import Thread

broker = "broker"
port = 1883
topic = "mqttTest"
messages_per_run = 1
threads = 1

counter = 0

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("Connected to MQTT broker successfully")
    else:
        print(f"Failed to connect, return code {rc}")

def mqtt_flood():
    global counter
    client = mqtt.Client()
    client.on_connect = on_connect
    client.connect(broker, port, 60)
    client.loop_start()
    try:
        while True:
            for _ in range(messages_per_run):
                counter += 1
                message = f"Payload: {counter}"
                client.publish(topic, message)
                print(f"Sent message: {message}")
            time.sleep(0.1)
    except KeyboardInterrupt:
        print("[-] Canceled by user")
        client.loop_stop()
        client.disconnect()

try:
    print("Starting MQTT Flooder...\n")
    for _ in range(threads):
        t = Thread(target=mqtt_flood)
        t.start()
except KeyboardInterrupt:
    print("[-] Canceled by user")
