import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

const serviceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const charUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
const bleName = 'VP-Lampu';

const cyan = Color(0xFF22E5FF);
const bg = Color(0xFF0B0F14);
const cardBg = Color(0xFF10161D);
const line = Color(0xFF17323A);

// 100 mode = 5 engine x 20 palet (urutan HARUS sama dengan firmware).
const engines = ['Static', 'Flow', 'Comet', 'Breathe', 'Sparkle'];
const palettes = [
  'Rainbow', 'Fire', 'Ice', 'Ocean', 'Forest', 'Sunset', 'Party', 'Red', 'Green', 'Blue',
  'Purple', 'Pink', 'Cyan', 'Yellow', 'Orange', 'White', 'Aurora', 'Lava', 'Neon', 'Candy'
];
final presetNames = [for (final e in engines) for (final p in palettes) '$e - $p'];

// 20 gaya custom (urutan HARUS sama dengan runCustom() di firmware).
const styles = <(String, IconData)>[
  ('Diam', Icons.circle),
  ('Kejar', Icons.keyboard_double_arrow_right),
  ('Teater', Icons.view_column_rounded),
  ('Bernapas', Icons.favorite_rounded),
  ('Komet', Icons.star_rounded),
  ('Gelombang', Icons.waves_rounded),
  ('Meteor', Icons.rocket_launch_rounded),
  ('Kerlip', Icons.auto_awesome),
  ('Berkedip', Icons.flash_on_rounded),
  ('Strobo', Icons.flare_rounded),
  ('Scanner', Icons.swap_horiz_rounded),
  ('Api', Icons.local_fire_department_rounded),
  ('Tengah', Icons.open_in_full_rounded),
  ('Isi', Icons.format_color_fill_rounded),
  ('Detak', Icons.monitor_heart_rounded),
  ('3 Titik', Icons.more_horiz_rounded),
  ('Pelangi', Icons.palette_rounded),
  ('Bintang', Icons.star_border_rounded),
  ('Bertemu', Icons.compare_arrows_rounded),
  ('Selang', Icons.grid_view_rounded),
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));
  runApp(MaterialApp(
    title: 'ALIS PROJECT',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true).copyWith(scaffoldBackgroundColor: bg),
    home: const LedPage(),
  ));
}

class LedPage extends StatefulWidget {
  const LedPage({super.key});
  @override
  State<LedPage> createState() => _LedPageState();
}

class _LedPageState extends State<LedPage> {
  BluetoothCharacteristic? ch;
  bool connecting = false, reverse = false;
  int tab = 0, preset = -1, style = 0; // preset -1 = Off
  double hue = 190, speed = 55, bright = 54;
  DateTime _last = DateTime(2000);

  Color get color => HSVColor.fromAHSV(1, hue, 1, 1).toColor();
  String get hex => '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  void _set(VoidCallback f) {
    setState(f);
    _send();
  }

  // Paket: [tipe, idx, R, G, B, speed, bright, arah]
  Future<void> _send({bool force = false}) async {
    if (ch == null) {
      if (force) _toast('Belum terhubung ke perangkat');
      return;
    }
    final now = DateTime.now();
    if (!force && now.difference(_last).inMilliseconds < 70) return;
    _last = now;
    final c = color;
    final List<int> data = tab == 0
        ? [preset < 0 ? 0 : 1, math.max(preset, 0), 0, 0, 0, speed.round(), bright.round(), 0]
        : [2, style, (c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round(), speed.round(), bright.round(), reverse ? 1 : 0];
    try {
      await ch!.write(data, withoutResponse: true);
      if (force) HapticFeedback.mediumImpact();
    } catch (_) {
      _toast('Gagal mengirim data');
    }
  }

  Future<void> connect() async {
    if (connecting || ch != null) return;
    setState(() => connecting = true);
    try {
      await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
      await FlutterBluePlus.startScan(withNames: [bleName], timeout: const Duration(seconds: 8));
      final r = await FlutterBluePlus.scanResults.firstWhere((l) => l.isNotEmpty).timeout(const Duration(seconds: 8));
      await FlutterBluePlus.stopScan();
      final d = r.first.device;
      await d.connect();
      for (final s in await d.discoverServices()) {
        if (s.uuid.str.toLowerCase() == serviceUuid) {
          for (final c in s.characteristics) {
            if (c.uuid.str.toLowerCase() == charUuid) ch = c;
          }
        }
      }
      d.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected && mounted) setState(() => ch = null);
      });
      HapticFeedback.mediumImpact();
    } catch (_) {
      _toast('Perangkat "$bleName" tidak ditemukan');
    }
    if (mounted) setState(() => connecting = false);
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF1C2630)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          Column(children: [_header(), Expanded(child: tab == 0 ? _presetTab() : _customTab())]),
          if (tab == 1)
            Positioned(
              left: 18,
              right: 18,
              bottom: 12,
              child: SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: () => _send(force: true),
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('TERAPKAN KE PERANGKAT', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
                  style: FilledButton.styleFrom(
                      backgroundColor: cyan, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
                ),
              ),
            ),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: cardBg,
        indicatorColor: cyan.withValues(alpha: 0.18),
        selectedIndex: tab,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          setState(() => tab = i);
          _send();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome, color: cyan), label: 'Mode LED'),
          NavigationDestination(icon: Icon(Icons.tune_rounded), selectedIcon: Icon(Icons.tune_rounded, color: cyan), label: 'Custom'),
        ],
      ),
    );
  }

  Widget _header() {
    final on = ch != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('ALIS PROJECT', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1)),
          Text('Kontrol lampu alis motor', style: TextStyle(color: Colors.white54, fontSize: 13)),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: connect,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: on ? const Color(0xFF3DDC84) : Colors.white24),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              connecting
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.circle, size: 10, color: on ? const Color(0xFF3DDC84) : Colors.redAccent),
              const SizedBox(width: 8),
              Text(connecting ? 'Mencari…' : on ? 'Terhubung' : 'Hubungkan', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ---------- TAB 1: MODE LED (100 preset) ----------
  Widget _presetTab() => ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 24), children: [
        _card(
          'RGB ENGINE',
          sub: '100 mode LED tersedia',
          trailing: Icon(Icons.circle, size: 12, color: ch != null ? cyan : Colors.white24),
          child: GestureDetector(
            onTap: _openSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: cyan.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: cyan.withValues(alpha: 0.45), width: 1.5),
              ),
              child: Row(children: [
                const Icon(Icons.auto_awesome, color: cyan, size: 30),
                const SizedBox(width: 18),
                Expanded(child: Text(preset < 0 ? 'Off' : presetNames[preset], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                const Icon(Icons.format_list_bulleted_rounded, color: cyan),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _card('PENGATURAN', sub: 'Kecepatan dan kecerahan', child: Column(children: [
          _slider(Icons.speed_rounded, 'Kecepatan', speed, (v) => _set(() => speed = v)),
          _slider(Icons.brightness_6_rounded, 'Kecerahan', bright, (v) => _set(() => bright = v)),
        ])),
      ]);

  void _openSheet() {
    String q = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F141A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final items = [
          for (int i = -1; i < 100; i++)
            if ((i < 0 ? 'off' : presetNames[i].toLowerCase()).contains(q.toLowerCase())) i
        ];
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.85,
            child: Column(children: [
              const SizedBox(height: 10),
              Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  onChanged: (v) => setS(() => q = v),
                  decoration: InputDecoration(
                    hintText: 'Cari mode LED...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: const Color(0xFF12222B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, k) {
                    final i = items[k];
                    final sel = i == preset;
                    return ListTile(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _set(() => preset = i);
                        Navigator.pop(ctx);
                      },
                      leading: Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: sel ? cyan : Colors.white38, size: 28),
                      title: Text(i < 0 ? 'Off' : presetNames[i],
                          style: TextStyle(fontSize: 17, fontWeight: sel ? FontWeight.w800 : FontWeight.w500, color: sel ? cyan : Colors.white)),
                    );
                  },
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  // ---------- TAB 2: CUSTOM ----------
  Widget _customTab() => ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 90), children: [
        _card('WARNA', child: Center(child: ColorRing(hue: hue, hex: hex, onChanged: (h) => _set(() => hue = h), onEnd: () => _send(force: true)))),
        const SizedBox(height: 14),
        _card('GAYA GERAKAN', sub: '${styles.length} gaya tersedia', child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.92,
          children: [for (int i = 0; i < styles.length; i++) _styleTile(i)],
        )),
        const SizedBox(height: 14),
        _card('ARAH & KECEPATAN', child: Column(children: [
          _direction(),
          const SizedBox(height: 18),
          _slider(Icons.speed_rounded, 'Kecepatan', speed, (v) => _set(() => speed = v)),
          _slider(Icons.brightness_6_rounded, 'Kecerahan', bright, (v) => _set(() => bright = v)),
        ])),
      ]);

  Widget _styleTile(int i) {
    final sel = style == i;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _set(() => style = i);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: sel ? cyan.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? cyan : Colors.white12, width: sel ? 1.5 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(styles[i].$2, size: 25, color: sel ? cyan : Colors.white60),
          const SizedBox(height: 6),
          Text(styles[i].$1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? Colors.white : Colors.white60)),
        ]),
      ),
    );
  }

  Widget _direction() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          for (final r in [false, true])
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _set(() => reverse = r);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: reverse == r ? cyan.withValues(alpha: 0.18) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: reverse == r ? cyan : Colors.transparent),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(r ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded, size: 18, color: reverse == r ? cyan : Colors.white54),
                    const SizedBox(width: 8),
                    Text(r ? 'Mundur' : 'Maju', style: TextStyle(fontWeight: FontWeight.w700, color: reverse == r ? Colors.white : Colors.white54)),
                  ]),
                ),
              ),
            ),
        ]),
      );

  // ---------- Komponen bersama ----------
  Widget _card(String title, {String? sub, Widget? trailing, required Widget child}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(26), border: Border.all(color: line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 2)),
                if (sub != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 13))),
              ]),
            ),
            if (trailing != null) trailing,
          ]),
          const SizedBox(height: 16),
          child,
        ]),
      );

  Widget _slider(IconData ic, String label, double v, ValueChanged<double> on) => Column(children: [
        Row(children: [
          Icon(ic, size: 18, color: Colors.white54),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 15, color: Colors.white70)),
          const Spacer(),
          Text('${v.round()}%', style: const TextStyle(color: cyan, fontWeight: FontWeight.w800)),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 8,
            activeTrackColor: cyan,
            inactiveTrackColor: Colors.white12,
            thumbColor: Colors.white,
            overlayColor: cyan.withValues(alpha: 0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
          ),
          child: Slider(value: v, min: 0, max: 100, onChanged: on, onChangeEnd: (_) => _send(force: true)),
        ),
      ]);
}

// ---------- Roda warna (satu-satunya elemen yang berubah warna) ----------
class ColorRing extends StatelessWidget {
  final double hue;
  final String hex;
  final ValueChanged<double> onChanged;
  final VoidCallback onEnd;
  const ColorRing({super.key, required this.hue, required this.hex, required this.onChanged, required this.onEnd});

  static const double size = 260;

  void _update(Offset p) {
    final a = math.atan2(p.dy - size / 2, p.dx - size / 2);
    onChanged((a * 180 / math.pi + 360) % 360);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onPanStart: (d) => _update(d.localPosition),
        onPanUpdate: (d) => _update(d.localPosition),
        onPanEnd: (_) => onEnd(),
        onTapDown: (d) => _update(d.localPosition),
        onTapUp: (_) => onEnd(),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(alignment: Alignment.center, children: [
            CustomPaint(size: const Size(size, size), painter: _RingPainter(hue)),
            Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('MX',
                  style: TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                      shadows: [Shadow(color: cyan, blurRadius: 18)])),
              Text(hex, style: const TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      );
}

class _RingPainter extends CustomPainter {
  final double hue;
  _RingPainter(this.hue);

  @override
  void paint(Canvas canvas, Size s) {
    const stroke = 50.0;
    final c = s.center(Offset.zero);
    final r = s.width / 2 - stroke / 2 - 4;
    final rect = Rect.fromCircle(center: c, radius: r);
    final shader = SweepGradient(colors: [for (int h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor()]).createShader(rect);
    canvas.drawCircle(c, r, Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
      ..color = Colors.white.withValues(alpha: 0.5));
    canvas.drawCircle(c, r, Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke);
    canvas.drawCircle(c, r - stroke / 2 - 3, Paint()..color = const Color(0xFF07070C));
    final a = hue * math.pi / 180;
    final t = c + Offset(math.cos(a), math.sin(a)) * r;
    canvas.drawCircle(t, 17, Paint()
      ..color = Colors.black38
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(t, 15, Paint()..color = Colors.white);
    canvas.drawCircle(t, 9, Paint()..color = HSVColor.fromAHSV(1, hue, 1, 1).toColor());
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.hue != hue;
}
