import json
import time
import os
from datetime import datetime
import pytz
import certifi
from dotenv import load_dotenv

import firebase_admin
from firebase_admin import credentials, firestore
import paho.mqtt.client as mqtt

# Загрузка .env
load_dotenv()
BROKER = os.getenv("MQTT_BROKER")
PORT = int(os.getenv("MQTT_PORT", "8883"))
USERNAME = os.getenv("MQTT_USERNAME")
PASSWORD = os.getenv("MQTT_PASSWORD")
SERVICE_ACCOUNT = os.getenv("SERVICE_ACCOUNT_PATH")
TOPIC_COMMAND = "devices/esp32_001/command"
TOPIC_ACK = "devices/esp32_001/ack"

# Firebase
cred = credentials.Certificate(SERVICE_ACCOUNT)
firebase_admin.initialize_app(cred)
db = firestore.client()

# Время и логика
TZ = pytz.timezone("Europe/Moscow")
sent_log = set()
current_day = datetime.now(TZ).day
ack_received = {}


# Подтверждение от ESP32
def on_message(client, userdata, msg):
    try:
        data = json.loads(msg.payload.decode())
        cell = data.get("cell")
        name = data.get("name")
        status = data.get("status")
        if status == "ok" and cell is not None:
            key = f"{cell}:{name}"
            ack_received[key] = True
            print(f"✅ Подтверждение от ESP32: ячейка {cell}, препарат {name}")
    except Exception as e:
        print(f"❌ Ошибка обработки ack: {e}")


def get_now():
    now = datetime.now(TZ)
    return now.strftime("%H:%M"), now.strftime("%a"), now.day


def get_russian_day(day_eng):
    return {
        "Mon": "Пн", "Tue": "Вт", "Wed": "Ср", "Thu": "Чт",
        "Fri": "Пт", "Sat": "Сб", "Sun": "Вс"
    }.get(day_eng, "")


def create_mqtt_client():
    client = mqtt.Client(protocol=mqtt.MQTTv311)
    client.username_pw_set(USERNAME, PASSWORD)
    client.tls_set(certifi.where())
    client.on_message = on_message
    return client


def send_to_esp32_until_ack(commands):
    global ack_received
    payload = {
        "action": "rotate",
        "commands": commands
    }
    message = json.dumps(payload, ensure_ascii=False)
    keys = [f"{cmd['cell']}:{cmd['name']}" for cmd in commands]
    first_attempt = True

    while True:
        ack_received = {}

        try:
            client = create_mqtt_client()
            client.connect(BROKER, PORT)
            client.subscribe(TOPIC_ACK)
            client.loop_start()
            client.publish(TOPIC_COMMAND, message)

            print(f"\n📤 Отправлено в ESP32 {'(повтор)' if not first_attempt else ''}:\n{message}")

            start_time = time.time()
            while time.time() - start_time < 20:
                if all(k in ack_received for k in keys):
                    client.loop_stop()
                    client.disconnect()
                    print("✅ Все подтверждения получены.")
                    return True
                time.sleep(1)

            client.loop_stop()
            client.disconnect()
            time.sleep(1)

            pending = [k for k in keys if k not in ack_received]
            print("⚠️ Нет подтверждения от:", pending)

            if first_attempt:
                with open("unsent.log", "a", encoding="utf-8") as f:
                    for p in pending:
                        f.write(f"{datetime.now(TZ)} — НЕ ПОДТВЕРЖДЕНО: {p}\n")

            print("🔁 Повторная попытка через 5 секунд...")
            time.sleep(5)
            first_attempt = False

        except Exception as e:
            print(f"❌ Ошибка MQTT: {type(e).__name__} — {e}")
            time.sleep(5)


def check_and_send():
    global sent_log, current_day
    now_time, now_day_eng, now_day_int = get_now()
    now_day_rus = get_russian_day(now_day_eng)

    if now_day_int != current_day:
        sent_log.clear()
        current_day = now_day_int
        print("🔄 Новый день: лог очищен.")

    print(f"\n🕒 Проверка: {now_time} | День: {now_day_rus}")
    commands = []

    try:
        docs = db.collection("cells").stream()
        for doc in docs:
            data = doc.to_dict()
            cell_index = doc.id
            medications = data.get("medications", [])

            if not isinstance(medications, list):
                continue

            for med in medications:
                name = med.get("title", "Без названия")
                dosage = med.get("quantity", 1)
                times = med.get("times", [])
                days = med.get("days", [])

                if now_day_rus not in days:
                    continue

                for t in times:
                    try:
                        now_dt = datetime.strptime(now_time, "%H:%M")
                        med_dt = datetime.strptime(t, "%H:%M")
                        diff = abs((med_dt - now_dt).total_seconds()) / 60
                        key = f"{cell_index}:{name}:{t}"
                        if diff <= 2 and key not in sent_log:
                            commands.append({
                                "cell": int(cell_index),
                                "name": name,
                                "dosage": dosage,
                                "time": t
                            })
                            sent_log.add(key)
                    except ValueError:
                        continue

        if commands:
            print(f"✅ Назначений найдено: {len(commands)}")
            send_to_esp32_until_ack(commands)
        else:
            print("🟡 Нет актуальных назначений.")
    except Exception as e:
        print(f"⚠️ Ошибка Firestore: {type(e).__name__} — {e}")


def run_service():
    print("🚀 Сервис запущен. Проверка каждую минуту.")
    while True:
        try:
            check_and_send()
            time.sleep(60)
        except KeyboardInterrupt:
            print("🛑 Остановлено пользователем.")
            break
        except Exception as e:
            print(f"⚠️ Ошибка сервиса: {type(e).__name__} — {e}")
            time.sleep(10)


if __name__ == "__main__":
    run_service()
