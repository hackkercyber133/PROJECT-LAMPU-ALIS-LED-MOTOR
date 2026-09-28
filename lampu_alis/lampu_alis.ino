// ALIS PROJECT - lampu alis motor: ESP32-C3 + WS2812B + BLE
// Library eksternal: FastLED saja (BLE bawaan core ESP32)
// Paket BLE (8 byte): [tipe, idx, R, G, B, speed(0-100), brightness(0-100), arah]
//   tipe 0 = Off | tipe 1 = preset (idx 0-99) | tipe 2 = custom (idx 0-19, pakai RGB + arah)

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <FastLED.h>

// ====== SESUAIKAN ======
#define LED_PIN   4
#define NUM_LEDS  30
#define BLE_NAME  "VP-Lampu"
// =======================

#define SERVICE_UUID "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
#define CHAR_UUID    "6e400002-b5a3-f393-e0a9-e50e24dcca9e"

CRGB leds[NUM_LEDS];

volatile uint8_t gType = 0, gIdx = 0, gR = 0, gG = 229, gB = 255;
volatile uint8_t gSpeed = 55, gBright = 54;
volatile bool gReverse = false;
uint32_t pos = 0, lastFrame = 0;

int wrapIdx(int i) { return ((i % NUM_LEDS) + NUM_LEDS) % NUM_LEDS; }

// ---------- 20 palet (urutan sama dengan aplikasi) ----------
const uint32_t PAL[20][4] = {
  {0, 0, 0, 0},                                          // 0 Rainbow (pakai RainbowColors_p)
  {0xFF0000, 0xFF6600, 0xFFCC00, 0xFF3300},              // 1 Fire
  {0xFFFFFF, 0x99E6FF, 0x0088FF, 0x00FFEE},              // 2 Ice
  {0x0000FF, 0x0088FF, 0x00FFCC, 0x0022AA},              // 3 Ocean
  {0x006600, 0x00CC33, 0x99FF00, 0x004400},              // 4 Forest
  {0xFF0033, 0xFF6600, 0xFFCC00, 0x9900FF},              // 5 Sunset
  {0xFF00FF, 0x00FFFF, 0xFFFF00, 0xFF0066},              // 6 Party
  {0xFF0000, 0x880000, 0xFF0000, 0x440000},              // 7 Red
  {0x00FF00, 0x008800, 0x00FF00, 0x004400},              // 8 Green
  {0x0000FF, 0x000088, 0x0000FF, 0x000044},              // 9 Blue
  {0x9900FF, 0x5500AA, 0xCC33FF, 0x330066},              // 10 Purple
  {0xFF00AA, 0xFF66CC, 0xFF0066, 0xFFAADD},              // 11 Pink
  {0x00FFFF, 0x008888, 0x00FFFF, 0x004444},              // 12 Cyan
  {0xFFFF00, 0x888800, 0xFFFF00, 0x444400},              // 13 Yellow
  {0xFF6600, 0x883300, 0xFF8800, 0x441A00},              // 14 Orange
  {0xFFFFFF, 0x888888, 0xFFFFFF, 0x444444},              // 15 White
  {0x00FF88, 0x0088FF, 0x8800FF, 0x00FFCC},              // 16 Aurora
  {0x330000, 0xFF0000, 0xFF6600, 0x660000},              // 17 Lava
  {0x39FF14, 0xFF073A, 0x04D9FF, 0xFFF01F},              // 18 Neon
  {0xFF99CC, 0x99CCFF, 0xFFFF99, 0xCC99FF}               // 19 Candy
};

CRGBPalette16 getPal(uint8_t p) {
  if (p == 0) return CRGBPalette16(RainbowColors_p);
  return CRGBPalette16(CRGB(PAL[p][0]), CRGB(PAL[p][1]), CRGB(PAL[p][2]), CRGB(PAL[p][3]));
}

// ---------- 100 preset: idx = engine*20 + palet ----------
// Engine: 0 Static, 1 Flow, 2 Comet, 3 Breathe, 4 Sparkle
void runPreset() {
  uint8_t engine = gIdx / 20;
  CRGBPalette16 pal = getPal(gIdx % 20);
  switch (engine) {
    case 0:
      for (int i = 0; i < NUM_LEDS; i++) leds[i] = ColorFromPalette(pal, (uint8_t)(i * 255 / NUM_LEDS));
      break;
    case 1:
      for (int i = 0; i < NUM_LEDS; i++) leds[i] = ColorFromPalette(pal, (uint8_t)(i * 255 / NUM_LEDS + pos * 2));
      break;
    case 2:
      fadeToBlackBy(leds, NUM_LEDS, 50);
      leds[pos % NUM_LEDS] = ColorFromPalette(pal, (uint8_t)(pos * 3));
      break;
    case 3: {
      uint8_t v = beatsin8(map(gSpeed, 0, 100, 6, 40), 40, 255);
      for (int i = 0; i < NUM_LEDS; i++) leds[i] = ColorFromPalette(pal, (uint8_t)(i * 255 / NUM_LEDS), v);
      break;
    }
    default:
      fadeToBlackBy(leds, NUM_LEDS, 40);
      if (random8() < 100) leds[random16(NUM_LEDS)] = ColorFromPalette(pal, random8());
  }
}

// ---------- 20 gaya custom (1 warna) ----------
void runCustom() {
  CRGB color = CRGB(gR, gG, gB);
  int N = NUM_LEDS;
  int sgn = gReverse ? -1 : 1;
  int off = sgn * (int)pos;

  switch (gIdx) {
    case 0: fill_solid(leds, N, color); break;                                   // Diam
    case 1:                                                                      // Kejar
      for (int i = 0; i < N; i++) leds[i] = (wrapIdx(i + off) % 4 == 0) ? color : CRGB::Black;
      break;
    case 2:                                                                      // Teater
      for (int i = 0; i < N; i++) leds[i] = (wrapIdx(i + off) % 4 < 2) ? color : CRGB::Black;
      break;
    case 3: {                                                                    // Bernapas
      CRGB c = color;
      c.nscale8(beatsin8(map(gSpeed, 0, 100, 6, 40), 20, 255));
      fill_solid(leds, N, c);
      break;
    }
    case 4:                                                                      // Komet
      fadeToBlackBy(leds, N, 50);
      leds[wrapIdx(off)] = color;
      break;
    case 5:                                                                      // Gelombang
      for (int i = 0; i < N; i++) {
        CRGB c = color;
        c.nscale8(sin8((i * 255 * 2) / N + off * 6));
        leds[i] = c;
      }
      break;
    case 6:                                                                      // Meteor
      for (int i = 0; i < N; i++) if (random8() > 100) leds[i].fadeToBlackBy(70);
      for (int j = 0; j < 4; j++) {
        CRGB c = color;
        c.nscale8(255 - j * 60);
        leds[wrapIdx(off - j * sgn)] = c;
      }
      break;
    case 7:                                                                      // Kerlip
      fadeToBlackBy(leds, N, 30);
      if (random8() < 90) leds[random16(N)] = color;
      break;
    case 8: fill_solid(leds, N, ((pos / 6) % 2) ? CRGB::Black : color); break;   // Berkedip
    case 9: fill_solid(leds, N, (pos % 8 == 0) ? color : CRGB::Black); break;    // Strobo
    case 10: {                                                                   // Scanner
      int p = pos % (2 * (N - 1));
      int idx = p < N ? p : 2 * (N - 1) - p;
      if (gReverse) idx = N - 1 - idx;
      fadeToBlackBy(leds, N, 60);
      leds[idx] = color;
      break;
    }
    case 11:                                                                     // Api
      for (int i = 0; i < N; i++) {
        CRGB c = color;
        c.nscale8(random8(90, 255));
        leds[i] = c;
      }
      break;
    case 12: {                                                                   // Tengah-Keluar
      int r = pos % (N / 2 + 2);
      for (int i = 0; i < N; i++) {
        int d = abs(2 * i - (N - 1)) / 2;
        bool lit = gReverse ? (d >= N / 2 - r) : (d <= r);
        leds[i] = lit ? color : CRGB::Black;
      }
      break;
    }
    case 13: {                                                                   // Isi
      int cnt = pos % (N + 1);
      for (int i = 0; i < N; i++) leds[i] = ((gReverse ? N - 1 - i : i) < cnt) ? color : CRGB::Black;
      break;
    }
    case 14: {                                                                   // Detak
      uint8_t t = pos % 40;
      uint8_t v = t < 4 ? 255 : t < 8 ? 60 : t < 12 ? 200 : t < 16 ? 40 : 10;
      CRGB c = color;
      c.nscale8(v);
      fill_solid(leds, N, c);
      break;
    }
    case 15: {                                                                   // Tiga Titik
      int gap = N / 3 > 0 ? N / 3 : 1;
      for (int i = 0; i < N; i++) leds[i] = (wrapIdx(i + off) % gap == 0) ? color : CRGB::Black;
      break;
    }
    case 16: {                                                                   // Pelangi (mulai dari warna pilihan)
      CHSV h = rgb2hsv_approximate(color);
      for (int i = 0; i < N; i++) leds[i] = CHSV((uint8_t)(h.hue + off * 3 + i * 255 / N), 255, 255);
      break;
    }
    case 17:                                                                     // Bintang
      fadeToBlackBy(leds, N, 10);
      if (random8() < 40) leds[random16(N)] = color;
      break;
    case 18: {                                                                   // Bertemu
      fadeToBlackBy(leds, N, 60);
      int a = pos % N;
      leds[a] = color;
      leds[N - 1 - a] = color;
      break;
    }
    case 19:                                                                     // Selang-seling
      for (int i = 0; i < N; i++) leds[i] = (((i + pos / 8) % 2) == 0) ? color : CRGB::Black;
      break;
    default: fill_solid(leds, N, color);
  }
}

void runEffect() {
  if (gType == 1) runPreset();
  else if (gType == 2) runCustom();
  else fill_solid(leds, NUM_LEDS, CRGB::Black);
}

// ---------- BLE ----------
class WriteCb : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) {
    auto v = c->getValue();
    if (v.length() < 8) return;
    gType = (uint8_t)v[0];
    gIdx = (uint8_t)v[1];
    gR = (uint8_t)v[2];
    gG = (uint8_t)v[3];
    gB = (uint8_t)v[4];
    gSpeed = (uint8_t)v[5];
    gBright = (uint8_t)v[6];
    gReverse = ((uint8_t)v[7]) != 0;
    if (gSpeed > 100) gSpeed = 100;
    if (gBright > 100) gBright = 100;
    FastLED.setBrightness(map(gBright, 0, 100, 0, 255));
  }
};

class ServerCb : public BLEServerCallbacks {
  void onConnect(BLEServer* s) {}
  void onDisconnect(BLEServer* s) { BLEDevice::startAdvertising(); }
};

void setup() {
  FastLED.addLeds<WS2812B, LED_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setMaxPowerInVoltsAndMilliamps(5, 2000);  // batas arus aman
  FastLED.setBrightness(map(gBright, 0, 100, 0, 255));

  BLEDevice::init(BLE_NAME);
  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new ServerCb());
  BLEService* svc = server->createService(SERVICE_UUID);
  BLECharacteristic* ch = svc->createCharacteristic(
      CHAR_UUID, BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  ch->setCallbacks(new WriteCb());
  svc->start();

  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  BLEDevice::startAdvertising();
}

void loop() {
  uint32_t delayMs = map(gSpeed, 0, 100, 80, 5);
  if (millis() - lastFrame >= delayMs) {
    lastFrame = millis();
    runEffect();
    FastLED.show();
    pos++;
  }
}
