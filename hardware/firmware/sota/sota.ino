#include <WiFiManager.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <GyverOLED.h>
#include <ArduinoJson.h>
#include <time.h>

// MQTT
const char* mqtt_server = "cffc3c4dda0a4f0f88d3177e3cbb7234.s1.eu.hivemq.cloud";
const int mqtt_port = 8883;
const char* mqtt_user = "Ottobiss";
const char* mqtt_pass = "#Wag#Gloom123";
const char* topic_cmd = "devices/esp32_001/command";
const char* topic_ack = "devices/esp32_001/ack";

WiFiClientSecure wifiClient;
PubSubClient client(wifiClient);
GyverOLED<SSD1306_128x64, OLED_BUFFER> oled;

// Мотор
#define ENC_A 34
#define ENC_B 35
#define MOTOR_IN1 26
#define MOTOR_IN2 27
volatile long encTicks = 0;
int currentCell = 0;
const int ticksPerCell = 332;
const int totalCells = 15;

void IRAM_ATTR onEnc() {
  if (digitalRead(ENC_B)) encTicks++;
  else encTicks--;
}

void initMotor() {
  pinMode(ENC_A, INPUT_PULLUP);
  pinMode(ENC_B, INPUT_PULLUP);
  pinMode(MOTOR_IN1, OUTPUT);
  pinMode(MOTOR_IN2, OUTPUT);
  attachInterrupt(digitalPinToInterrupt(ENC_A), onEnc, RISING);
}

void rotateTo(int target) {
  int fwd = (target - currentCell + totalCells) % totalCells;
  int bwd = (currentCell - target + totalCells) % totalCells;
  bool cw = fwd <= bwd;
  int steps = (cw ? fwd : bwd) * ticksPerCell;

  digitalWrite(MOTOR_IN1, cw ? LOW : HIGH);
  digitalWrite(MOTOR_IN2, cw ? HIGH : LOW);
  encTicks = 0;
  while (abs(encTicks) < steps) delay(1);
  digitalWrite(MOTOR_IN1, LOW);
  digitalWrite(MOTOR_IN2, LOW);
  currentCell = target;
}

// OLED
void showLogo() {
  oled.clear();
  oled.setScale(2);
  oled.setCursor(15, 1);
  oled.print("SOTA");
  oled.setScale(1);
  oled.setCursor(10, 4);
  oled.print("Smart таблетница");
  oled.update();
  delay(2500);
}

void showOLED(const String& l1, const String& l2 = "", const String& l3 = "") {
  oled.clear();
  oled.setScale(1);
  oled.setCursor(0, 0); oled.print(l1);
  oled.setCursor(0, 2); oled.print(l2);
  oled.setCursor(0, 4); oled.print(l3);
  oled.update();
}

void showDose(const String& name, int cell, int dose) {
  oled.clear();
  oled.setScale(2);
  oled.setCursor(0, 0); oled.print(">> "); oled.print(name);

  oled.setScale(1);
  oled.setCursor(0, 4); oled.print("Ячейка: "); oled.print(cell);
  oled.setCursor(0, 6); oled.print("Доза: ");
  for (int i = 0; i < dose; i++) oled.print("+");

  oled.update();
  delay(10000);  // держим экран 10 секунд
}

void showWaiting() {
  oled.clear();
  oled.setCursor(0, 2);
  oled.setScale(2);
  oled.print("Ожидание");
  const char* dots[] = {".", "..", "..."};
  for (int i = 0; i < 6; i++) {
    oled.setCursor(0, 6);
    oled.setScale(1);
    oled.print(dots[i % 3]);
    oled.update();
    delay(400);
  }
}

void showRotating(const String& name) {
  const char* spin[] = {"/", "-", "\\", "|"};
  for (int i = 0; i < 8; i++) {
    oled.clear();
    oled.setCursor(0, 0); oled.print("Готовим:");
    oled.setCursor(0, 2); oled.print(name);
    oled.setCursor(0, 4); oled.print("Вращение ");
    oled.print(spin[i % 4]);
    oled.update();
    delay(120);
  }
}

void sendAck(int cell, const String& name) {
  StaticJsonDocument<256> ack;
  ack["status"] = "ok";
  ack["cell"] = cell;
  ack["name"] = name;
  char buf[256];
  serializeJson(ack, buf);
  client.publish(topic_ack, buf);
}

void callback(char* topic, byte* payload, unsigned int length) {
  payload[length] = '\0';
  StaticJsonDocument<1024> doc;
  if (deserializeJson(doc, payload)) return;
  if (doc["action"] != "rotate") return;

  JsonArray cmds = doc["commands"];
  for (JsonObject cmd : cmds) {
    int cell = cmd["cell"];
    int dose = cmd["dosage"];
    String name = cmd["name"].as<String>();

    showRotating(name);
    rotateTo(cell);
    showDose(name, cell, dose);
    sendAck(cell, name);
  }

  rotateTo(0);
  showWaiting();
}

void setupWiFi() {
  WiFiManager wm;
  showOLED("Подключитесь к", "SOTA", "и настройте сеть");
  if (!wm.autoConnect("SOTA")) ESP.restart();
  showOLED("✅ Подключено к", WiFi.SSID());
}

void setupMQTT() {
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  wifiClient.setInsecure();
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
}

void reconnectMQTT() {
  while (!client.connected()) {
    client.connect("esp32_tablet", mqtt_user, mqtt_pass);
    delay(1000);
  }
  client.subscribe(topic_cmd);
}

void setup() {
  Serial.begin(115200);
  oled.init();
  initMotor();
  showLogo();
  setupWiFi();
  setupMQTT();
  showWaiting();
}

void loop() {
  if (!client.connected()) reconnectMQTT();
  client.loop();
}
