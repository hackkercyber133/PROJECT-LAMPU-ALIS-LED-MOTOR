// Firmware lampu alis motor: ESP32-C3 + WS2812B + BLE
// Paket BLE (7 byte): [mode, R, G, B, speed(0-100), brightness(0-100), arah(0=maju,1=mundur)]
#include <Arduino.h>
#include <NimBLEDevice.h>
#include <FastLED.h>

// ====== SESUAIKAN ======
#define LED_PIN   4      // pin data LED
#define NUM_LEDS  30     // jumlah LED
#define BLE_NAME  "VP-Lampu"
// =======================

#define SERVICE_UUID "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
#define CHAR_UUID    "6e400002-b5a3-f393-e0a9-e50e24dcca9e"

CRGB leds[NUM_LEDS];

struct State {
  uint8_t mode = 0;
  CRGB color = CRGB::Cyan;
  uint8_t speed = 55;
  uint8_t bright = 54;
  bool reverse = false;
} st;

uint16_t pos = 0;
uint32_t lastFrame = 0;

static inline int wrap(int i) { return ((i % NUM_LEDS) + NUM_LEDS) % NUM_LEDS; }

// ---------- EFEK ----------
// 0 Diam, 1 Kejar, 2 Teater, 3 Bernapas, 4 Komet, 5 Gelombang, 6 Meteor, 7 Kerlip
void runEffect() {
  int sgn = st.reverse ? -1 : 1;
  int off = sgn * (int)pos;

  switch (st.mode) {
    case 0:  // Diam
      fill_solid(leds, NUM_LEDS, st.color);
      break;

    case 1:  // Kejar
      for (int i = 0; i < NUM_LEDS; i++)
        leds[i] = (wrap(i + off) % 4 == 0) ? st.color : CRGB::Black;
      break;

    case 2:  // Teater
      for (int i = 0; i < NUM_LEDS; i++)
        leds[i] = (wrap(i + off) % 4 < 2) ? st.color : CRGB::Black;
      break;

    case 3: {  // Bernapas
      uint8_t v = beatsin8(map(st.speed, 0, 100, 6, 40), 20, 255);
      CRGB c = st.color;
      c.nscale8(v);
      fill_solid(leds, NUM_LEDS, c);
      break;
    }

    case 4:  // Komet
      fadeToBlackBy(leds, NUM_LEDS, 50);
      leds[wrap(off)] = st.color;
      break;

    case 5:  // Gelombang
      for (int i = 0; i < NUM_LEDS; i++) {
        uint8_t v = sin8((i * 255 * 2) / NUM_LEDS + off * 6);
        CRGB c = st.color;
        c.nscale8(v);
        leds[i] = c;
      }
      break;

    case 6:  // Meteor
      for (int i = 0; i < NUM_LEDS; i++)
        if (random8() > 100) leds[i].fadeToBlackBy(70);
      for (int j = 0; j < 4; j++) {
        CRGB c = st.color;
        c.nscale8(255 - j * 60);
        leds[wrap(off - j * sgn)] = c;
      }
      break;

    case 7:  // Kerlip
      fadeToBlackBy(leds, NUM_LEDS, 30);
      if (random8() < 90) leds[random16(NUM_LEDS)] = st.color;
      break;

    default:
      fill_solid(leds, NUM_LEDS, st.color);
  }
}

// ---------- BLE ----------
class WriteCb : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* c) override {
    std::string v = c->getValue();
    if (v.size() < 7) return;
    st.mode    = (uint8_t)v[0];
    st.color   = CRGB((uint8_t)v[1], (uint8_t)v[2], (uint8_t)v[3]);
    st.speed   = min<uint8_t>((uint8_t)v[4], 100);
    st.bright  = min<uint8_t>((uint8_t)v[5], 100);
    st.reverse = v[6] != 0;
    FastLED.setBrightness(map(st.bright, 0, 100, 0, 255));
  }
};

class ServerCb : public NimBLEServerCallbacks {
  void onDisconnect(NimBLEServer*) override { NimBLEDevice::startAdvertising(); }
};

void setup() {
  FastLED.addLeds<WS2812B, LED_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setMaxPowerInVoltsAndMilliamps(5, 2000);  // batas arus aman
  FastLED.setBrightness(map(st.bright, 0, 100, 0, 255));

  NimBLEDevice::init(BLE_NAME);
  NimBLEServer* server = NimBLEDevice::createServer();
  server->setCallbacks(new ServerCb());
  NimBLEService* svc = server->createService(SERVICE_UUID);
  NimBLECharacteristic* ch = svc->createCharacteristic(
      CHAR_UUID, NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR);
  ch->setCallbacks(new WriteCb());
  svc->start();

  NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->start();
}

void loop() {
  uint32_t delayMs = map(st.speed, 0, 100, 80, 5);
  if (millis() - lastFrame >= delayMs) {
    lastFrame = millis();
    runEffect();
    FastLED.show();
    pos++;
  }
}
