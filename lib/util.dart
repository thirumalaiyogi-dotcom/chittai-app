// Crispy — பொது உதவி functions (index.html-ல் உள்ள அதே கணக்கு விதிகள்)
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

// ── JavaScript-ன் `+x` போல: எண்ணாக மாற்று (முடியாவிட்டால் NaN) ──
double jn(dynamic v) {
  if (v == null) return double.nan;
  if (v is num) return v.toDouble();
  if (v is bool) return v ? 1 : 0;
  final s = v.toString().trim();
  if (s.isEmpty) return 0;
  return double.tryParse(s) ?? double.nan;
}

// `+x||0`
double jz(dynamic v) {
  final n = jn(v);
  return n.isNaN ? 0 : n;
}

// JS-ல் உண்மை எண்ணா (0 / NaN இல்லை)
bool jt(dynamic v) {
  final n = jn(v);
  return !n.isNaN && n != 0;
}

String js(dynamic v) => v == null ? '' : v.toString();

bool jsTruthy(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0 && !v.isNaN;
  if (v is String) return v.isNotEmpty;
  return true;
}

// HTML: Math.round((n+Number.EPSILON)*100)/100
double round2(double n) => ((n + 2.220446049250313e-16) * 100).roundToDouble() / 100;

// 120 → "120", 12.5 → "12.5", 12.25 → "12.25"
String rupee(dynamic n) {
  final v = round2(jz(n));
  var s = v.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  if (s.isEmpty || s == '-') s = '0';
  return s;
}

// ── சலுகை: MRP > விலை இருந்தால் மட்டும் ──
class Offer {
  final double mrp, price;
  final int off;
  const Offer(this.mrp, this.price, this.off);
}

Offer? pkOfferRaw(dynamic price, dynamic mrp) {
  final pr = jn(price), mr = jn(mrp);
  if (pr.isNaN || mr.isNaN || pr.isInfinite || mr.isInfinite || pr <= 0 || !(mr > pr)) return null;
  final off = ((1 - pr / mr) * 100).round();
  if (off < 1) return null;
  return Offer(mr, pr, off);
}

// ── அளவு (pack) எடை: வரிசைப்படுத்த மட்டும் ──
double packWeightVal(String? w0) {
  if (w0 == null || w0.trim().isEmpty) return 999999;
  final w = w0.trim();
  double mUnit(String u) {
    u = u.trim();
    if (u.contains('கி.கி')) return 1000;
    if (u.contains('மி.லி')) return 1;
    if (u.contains('லி')) return 1000;
    if (u.contains('கி')) return 1;
    return 1;
  }

  final m = RegExp(r'^(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)\s*(.*)$', caseSensitive: false).firstMatch(w);
  if (m != null) return double.parse(m.group(1)!) * double.parse(m.group(2)!) * mUnit(m.group(3) ?? '');
  final m2 = RegExp(r'^(\d+(?:\.\d+)?)\s*(.*)$').firstMatch(w);
  if (m2 != null) return double.parse(m2.group(1)!) * mUnit(m2.group(2) ?? '');
  return 999999;
}

// inventory.sql pack_factor-ன் அதே விதி: ஒரு pack-க்கு எத்தனை அலகு
double invPackFactor(String w, String? unit, dynamic packq) {
  if (packq is Map) {
    final v = jn(packq[w]);
    if (!v.isNaN && v > 0) return v;
  }
  final s = w.toLowerCase();
  final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(s);
  var n = m != null ? double.parse(m.group(1)!) : 1.0;
  if (!(n > 0)) n = 1;
  if (unit == 'kg') {
    if (RegExp(r'(கி\.?\s?கி|கிலோ|kg|kilo)').hasMatch(s)) return n;
    if (RegExp(r'(கிராம்|கி|gm|gram|\d\s?g(\W|$))').hasMatch(s)) return n / 1000;
    return 1;
  }
  if (unit == 'l') {
    if (RegExp(r'(மி\.?\s?லி|ml)').hasMatch(s)) return n / 1000;
    if (RegExp(r'(லிட்டர்|லி|ltr|lit|\d\s?l(\W|$))').hasMatch(s)) return n;
    return 1;
  }
  if (RegExp(r'(பீஸ்|pcs|pc|nos|piece|எண்ணம்)').hasMatch(s)) return n;
  return 1;
}

// ── தூரம் (km) ──
double kmBetween(double a, double b, double c, double d) {
  const r = 6371.0;
  double rad(double x) => x * math.pi / 180;
  final dLa = rad(c - a), dLo = rad(d - b);
  final h = math.pow(math.sin(dLa / 2), 2) + math.cos(rad(a)) * math.cos(rad(c)) * math.pow(math.sin(dLo / 2), 2);
  return 2 * r * math.asin(math.sqrt(h));
}

// "21:00" → "இரவு 9:00"
String tTime(dynamic t) {
  final p = js(t).split(':');
  final h = int.tryParse(p[0].trim());
  if (h == null) return '';
  final mi = p.length > 1 ? (int.tryParse(p[1].trim()) ?? 0) : 0;
  final m = mi.toString().padLeft(2, '0');
  final w = h < 5
      ? 'இரவு'
      : h < 12
          ? 'காலை'
          : h < 16
              ? 'மதியம்'
              : h < 19
                  ? 'மாலை'
                  : 'இரவு';
  return '$w ${(h % 12) == 0 ? 12 : h % 12}:$m';
}

int? hmToMin(dynamic x) {
  final p = js(x).split(':');
  final h = int.tryParse(p[0].trim());
  if (h == null) return null;
  final m = p.length > 1 ? (int.tryParse(p[1].trim()) ?? 0) : 0;
  return h * 60 + m;
}

// ── HTML-ன் escape தேவையில்லை; WhatsApp எண் சரிசெய்தல் ──
String supNum(dynamic raw) {
  var d = js(raw).replaceAll(RegExp(r'\D'), '');
  if (d.length == 10) {
    d = '91$d';
  } else if (d.length == 11 && d.startsWith('0')) {
    d = '91${d.substring(1)}';
  }
  return RegExp(r'^\d{11,15}$').hasMatch(d) ? d : '';
}

// ── தமிழ் தேதி ──
const kTaMonthsShort = ['ஜன', 'பிப்', 'மார்', 'ஏப்', 'மே', 'ஜூன்', 'ஜூலை', 'ஆக', 'செப்', 'அக்', 'நவ', 'டிச'];
const kTaMonthsLong = ['ஜனவரி', 'பிப்ரவரி', 'மார்ச்', 'ஏப்ரல்', 'மே', 'ஜூன்', 'ஜூலை', 'ஆகஸ்ட்', 'செப்டம்பர்', 'அக்டோபர்', 'நவம்பர்', 'டிசம்பர்'];
const kTaWeekdays = ['ஞாயிறு', 'திங்கள்', 'செவ்வாய்', 'புதன்', 'வியாழன்', 'வெள்ளி', 'சனி'];

// ═══ HTML toLocale*('ta-IN') வடிவங்கள் (Chrome / CLDR) ═══
const kTaMonIcu = ['ஜன.', 'பிப்.', 'மார்.', 'ஏப்.', 'மே', 'ஜூன்', 'ஜூலை', 'ஆக.', 'செப்.', 'அக்.', 'நவ.', 'டிச.'];
// {day:'numeric', month:'short'} → "13 அக்."
String taDayMon(DateTime d) => '${d.day} ${kTaMonIcu[d.month - 1]}';
// {day, month:'short', year} → "13 அக்., 2026"
String taDayMonYear(DateTime d) => '${d.day} ${kTaMonIcu[d.month - 1]}, ${d.year}';
// {day, month:'long', year} → "13 அக்டோபர், 2026"
String taDayMonthYear(DateTime d) => '${d.day} ${kTaMonthsLong[d.month - 1]}, ${d.year}';
// toLocaleString('ta-IN') → "13/10/2026, முற்பகல் 5:18:00"
String taLocaleString(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  String p2(int x) => x.toString().padLeft(2, '0');
  return '${d.day}/${d.month}/${d.year}, ${d.hour < 12 ? 'முற்பகல்' : 'பிற்பகல்'} $h:${p2(d.minute)}:${p2(d.second)}';
}

String hm12(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

// ── அதிர்வு ──
void haptic([int ms = 12]) {
  try {
    if (ms > 20) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  } catch (_) {}
}

// ── ஒலிகள்: web app-ன் Web Audio ஒலிகளை இங்கேயே WAV-ஆக உருவாக்குகிறோம் (audio file தேவையில்லை) ──
class _Tone {
  final double at, dur, f0, f1, g0;
  final bool tri;
  const _Tone(this.at, this.dur, this.f0, this.f1, this.g0, this.tri);
}

class Sfx {
  static const int _rate = 22050;
  static final Map<String, Uint8List> _cache = {};
  static final Map<String, AudioPlayer> _players = {};
  static bool enabled = true;

  static Uint8List _wav(List<_Tone> tones) {
    var total = 0.0;
    for (final t in tones) {
      total = math.max(total, t.at + t.dur);
    }
    final n = (total * _rate).ceil() + 64;
    final buf = Float64List(n);
    for (final t in tones) {
      final start = (t.at * _rate).round();
      final len = (t.dur * _rate).round();
      var phase = 0.0;
      for (var i = 0; i < len && start + i < n; i++) {
        final x = i / len;
        final f = t.f0 * math.pow(t.f1 / t.f0, x);
        phase += 2 * math.pi * f / _rate;
        final g = t.g0 * math.pow(0.001 / t.g0, x);
        final s = t.tri ? (2 / math.pi) * math.asin(math.sin(phase)) : math.sin(phase);
        buf[start + i] += s * g;
      }
    }
    final data = ByteData(44 + n * 2);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    str(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (var i = 0; i < n; i++) {
      final v = (buf[i].clamp(-1.0, 1.0) * 32000).round();
      data.setInt16(44 + i * 2, v, Endian.little);
    }
    return data.buffer.asUint8List();
  }

  static Uint8List _sound(String k) {
    return _cache.putIfAbsent(k, () {
      switch (k) {
        case 'click':
          return _wav(const [_Tone(0, 0.06, 1200, 800, 0.3, false)]);
        case 'add':
          return _wav(const [_Tone(0, 0.12, 1500, 1500, 0.25, true), _Tone(0.06, 0.12, 1800, 1800, 0.25, true)]);
        case 'remove':
          return _wav(const [_Tone(0, 0.1, 600, 300, 0.2, false)]);
        default:
          return _wav(const [
            _Tone(0, 0.15, 1000, 1000, 0.2, true),
            _Tone(0.1, 0.15, 1300, 1300, 0.2, true),
            _Tone(0.2, 0.15, 1600, 1600, 0.2, true),
          ]);
      }
    });
  }

  static Future<void> _play(String k) async {
    if (!enabled) return;
    try {
      var p = _players[k];
      if (p == null) {
        p = AudioPlayer();
        try {
          await p.setAudioContext(AudioContext(
            android: AudioContextAndroid(
              audioFocus: AndroidAudioFocus.none,
              usageType: AndroidUsageType.assistanceSonification,
              contentType: AndroidContentType.sonification,
            ),
          ));
        } catch (_) {}
        await p.setReleaseMode(ReleaseMode.stop);
        _players[k] = p;
      }
      await p.stop();
      await p.play(BytesSource(_sound(k)), volume: 0.8);
    } catch (_) {}
  }

  static void click() => _play('click');
  static void add() => _play('add');
  static void remove() => _play('remove');
  static void checkout() => _play('checkout');
}

// பட்டியலில் முதல் உறுப்பு (இல்லையெனில் null)
extension First0<T> on Iterable<T> {
  T? get first0 {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
