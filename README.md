# ALIS PROJECT - Lampu Alis Motor (ESP32-C3 + BLE)

Isi:
- lampu_alis/lampu_alis.ino -> firmware (ArduinoDroid / Arduino IDE), library eksternal: FastLED
- flutter_app/              -> aplikasi Flutter (lib/main.dart, pubspec.yaml, tool/patch_android.py)
- codemagic.yaml            -> build APK otomatis di Codemagic (harus di root repo GitHub)

## Firmware
1. Pasang library FastLED. Buka lampu_alis.ino.
2. Edit LED_PIN (default 4) dan NUM_LEDS (default 30).
3. Pilih board ESP32-C3, Upload. Perangkat BLE bernama VP-Lampu.

## Aplikasi
Tab "Mode LED": 100 mode siap pakai (5 engine x 20 palet), cari lewat menu, atur kecepatan & kecerahan.
Tab "Custom": roda warna, 20 gaya gerakan, arah, kecepatan, kecerahan.

Build APK: upload seluruh isi zip ke GitHub (branch main), lalu Start new build di Codemagic.

## Protokol BLE
Service 6e400001-b5a3-f393-e0a9-e50e24dcca9e, Char 6e400002-b5a3-f393-e0a9-e50e24dcca9e (write)
Paket 8 byte: [tipe, idx, R, G, B, kecepatan 0-100, kecerahan 0-100, arah]
  tipe 0 = Off | 1 = preset (idx 0-99 = engine*20 + palet) | 2 = custom (idx 0-19)

## Tambah mode
- Gaya custom: tambah di daftar `styles` (main.dart) + case baru di runCustom() (firmware).
- Palet preset: tambah nama di `palettes` + baris di PAL[] (jumlah harus sama).

## Hardware
Stepdown 12V->5V min 3A + sekring, level shifter 74AHCT125 (atau resistor 330 ohm) di jalur data,
kapasitor 1000uF di +5V LED, semua GND disatukan.
