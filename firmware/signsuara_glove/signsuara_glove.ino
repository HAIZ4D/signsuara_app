// SignSuara glove: USB Serial CSV (unchanged, used by record_v2.py / live_v2.py) + BLE.
//
// BLE: device "SignSuara-Glove", one NOTIFY characteristic, one notification per row (25 Hz):
//   seq,thumb,index,middle,ring,pinky,yaw,pitch,roll,ax,ay,az
// = the exact Serial line with a row number (seq) in front and no newline.
// seq counts every row since power-on, so a gap in seq means the app missed rows.
// A row is up to ~85 bytes but the default BLE packet is only 20, so the phone MUST request
// a bigger MTU (>= 100). If it doesn't, rows arrive cut off, and the app must reject them.
//
// Arduino IDE: keep Tools > Core Debug Level = "None", or BLE log lines appear on Serial.

#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BNO055.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLE2902.h>

const int PINS[5] = {36, 34, 35, 32, 33}; // thumb, index, middle, ring, pinky
Adafruit_BNO055 bno = Adafruit_BNO055(55, 0x28, &Wire);
unsigned long lastSample = 0;
int zeroCount = 0;

// ---------- BLE (new) ----------
#define SERVICE_UUID  "6b5384d0-483c-4d29-b3e7-4c404e3defce"
#define ROW_CHAR_UUID "2fce7dc7-6ea7-4d15-8e66-280c660ecb8b"
BLECharacteristic *rowChar;
volatile bool bleConnected = false;
unsigned long seq = 0;

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *server) override { bleConnected = true; }
  void onDisconnect(BLEServer *server) override {
    bleConnected = false;
    BLEDevice::startAdvertising(); // stay visible so the phone can reconnect
  }
};

// Collects printed text in memory, so Serial and BLE send exactly the same characters.
class LineBuffer : public Print {
 public:
  char text[100];
  size_t len = 0;
  size_t write(uint8_t c) override {
    if (len < sizeof(text)) text[len++] = c;
    return 1;
  }
};

void setupBle() {
  BLEDevice::init("SignSuara-Glove");
  BLEDevice::setMTU(185); // allow big packets (the phone must ask for a big MTU too)
  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());
  BLEService *service = server->createService(SERVICE_UUID);
  rowChar = service->createCharacteristic(ROW_CHAR_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  rowChar->addDescriptor(new BLE2902()); // lets the phone switch notifications on
  service->start();

  // An advertising packet holds only 31 bytes: the name (17) and the service UUID (18) don't
  // fit together. Name in the main packet so every scanner shows it, UUID in the scan response.
  BLEAdvertisementData advData, scanData;
  advData.setFlags(0x06); // discoverable, BLE only
  advData.setName("SignSuara-Glove");
  scanData.setCompleteServices(BLEUUID(SERVICE_UUID));
  BLEAdvertising *adv = BLEDevice::getAdvertising();
  adv->setAdvertisementData(advData);
  adv->setScanResponseData(scanData);
  BLEDevice::startAdvertising();
}

void setup() {
  Serial.begin(115200);
  setupBle(); // new: first, so the glove is visible even while waiting for the BNO055
  Wire.begin(21, 22);
  while (!bno.begin()) {
    Serial.println("# BNO055 not detected, retrying...");
    delay(1000);
  }
  bno.setExtCrystalUse(true);
  Serial.println("# thumb,index,middle,ring,pinky,yaw,pitch,roll,ax,ay,az");
}

void loop() {
  if (millis() - lastSample < 40) return; // 25 Hz
  lastSample = millis();

  sensors_event_t ori, acc;
  bno.getEvent(&ori, Adafruit_BNO055::VECTOR_EULER);
  bno.getEvent(&acc, Adafruit_BNO055::VECTOR_LINEARACCEL);

  // Auto-restart BNO055 if it freezes (all zeros)
  if (ori.orientation.x == 0 && ori.orientation.y == 0 && ori.orientation.z == 0) {
    if (++zeroCount > 10) {
      Serial.println("# BNO055 lost, restarting...");
      Wire.end(); Wire.begin(21, 22);
      bno.begin(); bno.setExtCrystalUse(true);
      zeroCount = 0;
    }
  } else {
    zeroCount = 0;
  }

  // Same prints as before, but into memory first
  LineBuffer line;
  for (int i = 0; i < 5; i++) {
    line.print(analogRead(PINS[i]));
    line.print(",");
  }
  line.print(ori.orientation.x); line.print(",");
  line.print(ori.orientation.y); line.print(",");
  line.print(ori.orientation.z); line.print(",");
  line.print(acc.acceleration.x); line.print(",");
  line.print(acc.acceleration.y); line.print(",");
  line.print(acc.acceleration.z);

  // USB Serial: byte-for-byte the same output as the old sketch
  Serial.write((const uint8_t *)line.text, line.len);
  Serial.println();

  // BLE: "seq," + the same text
  if (bleConnected) {
    char packet[120];
    int n = snprintf(packet, sizeof(packet), "%lu,%.*s", seq, (int)line.len, line.text);
    rowChar->setValue((uint8_t *)packet, n);
    rowChar->notify();
  }
  seq++;
}
