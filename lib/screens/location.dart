// Crispy — "டெலிவரி இடம் எங்கே?" sheet, வரைபட pin (இலவச OpenStreetMap), டெலிவரி விவரம் (முகவரி) sheet
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models.dart';
import '../nav.dart';
import '../orders.dart';
import '../state.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';

class MapPin {
  final double lat, lng;
  final String area, full;
  const MapPin(this.lat, this.lng, [this.area = '', this.full = '']);
}

// ═══ Nominatim (OpenStreetMap) — app பெயருடன், வினாடிக்கு ஒன்று மட்டும் ═══
class Geo {
  static const _ua = {'User-Agent': 'Chittai/1.0 (com.chittai.customer)', 'Accept-Language': 'ta,en'};

  static Future<Map<String, String>> reverse(double lat, double lng) async {
    final r = await http
        .get(Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=18&accept-language=ta,en&lat=$lat&lon=$lng'), headers: _ua)
        .timeout(const Duration(seconds: 12));
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    final a = d is Map && d['address'] is Map ? d['address'] as Map : const {};
    String f(String k) => js(a[k]);
    final sub = [f('neighbourhood'), f('suburb'), f('quarter'), f('village'), f('hamlet')].firstWhere((x) => x.isNotEmpty, orElse: () => '');
    final city = [f('town'), f('city'), f('county')].firstWhere((x) => x.isNotEmpty, orElse: () => '');
    final part = <String>[];
    for (final x in [f('house_number'), f('road'), sub, city, f('postcode')]) {
      if (x.isNotEmpty && !part.contains(x)) part.add(x);
    }
    final ar = <String>[];
    for (final x in [sub, city]) {
      if (x.isNotEmpty && !ar.contains(x)) ar.add(x);
    }
    final title = sub.isNotEmpty ? sub : (f('road').isNotEmpty ? f('road') : (city.isNotEmpty ? city : 'குறிக்கப்பட்ட இடம்'));
    return {'title': title, 'full': part.join(', '), 'area': ar.join(', ')};
  }

  static Future<List<Map<String, dynamic>>?> search(String q, double lat, double lng) async {
    try {
      final u = 'https://nominatim.openstreetmap.org/search?format=jsonv2&countrycodes=in&limit=6&accept-language=ta,en'
          '&viewbox=${lng - 0.4},${lat + 0.4},${lng + 0.4},${lat - 0.4}&q=${Uri.encodeComponent(q)}';
      final r = await http.get(Uri.parse(u), headers: _ua).timeout(const Duration(seconds: 12));
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      if (d is! List) return [];
      return d.whereType<Map>().map((x) {
        final parts = js(x['display_name']).split(', ');
        return <String, dynamic>{'main': parts[0], 'sub': parts.skip(1).take(3).join(', '), 'lat': jn(x['lat']), 'lng': jn(x['lon'])};
      }).toList();
    } catch (_) {
      return null;
    }
  }
}

// ═══ GPS ═══
class Gps {
  // அனுமதி: null = சரி, இல்லையெனில் பிழைக் குறியீடு (1 = மறுப்பு)
  static Future<int?> ensure() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return 2;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return 1;
      return null;
    } catch (_) {
      return 2;
    }
  }

  static Future<Position?> once() async {
    final e = await ensure();
    if (e != null) {
      AppState.I.locState = e == 1 ? 'denied' : 'unavail';
      return null;
    }
    try {
      final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
      AppState.I.setUserLoc(p.latitude, p.longitude);
      if (p.accuracy > 500) {
        toast('📍 இடம் துல்லியமாக இல்லை (±${p.accuracy.round()} மீ). Settings → Location → "Precise location" ON செய்யுங்கள்');
      }
      return p;
    } catch (_) {
      try {
        final p = await Geolocator.getLastKnownPosition();
        if (p != null) AppState.I.setUserLoc(p.latitude, p.longitude);
        return p;
      } catch (_) {
        return null;
      }
    }
  }
}

LatLng mapStartPos({MapPin? pin}) {
  final s = AppState.I;
  if (pin != null) return LatLng(pin.lat, pin.lng);
  final p = s.profRaw();
  if (p['lat'] != null) return LatLng(jz(p['lat']), jz(p['lng']));
  if (s.userLat != null) return LatLng(s.userLat!, s.userLng!);
  final cs = s.shopById(s.cartShopId ?? s.activeShop);
  if (cs != null && cs.lat != null) return LatLng(cs.lat!, cs.lng!);
  return const LatLng(8.7139, 77.7567); // திருநெல்வேலி
}

// ═══ வரைபடத்தில் pin வைத்தல் ═══
Future<MapPin?> openMapPick({LatLng? at, double acc = 0, MapPin? current}) {
  final c = Nav.ctx;
  if (c == null) return Future.value(null);
  return Navigator.of(c).push<MapPin>(MaterialPageRoute(builder: (_) => MapPickScreen(at: at, acc: acc, current: current)));
}

// cart / location sheet-லிருந்து: pin-ஐ சுயவிவரத்தில் சேமி
void savePinToProfile(MapPin pin) {
  final p = AppState.I.profRaw();
  p['lat'] = pin.lat;
  p['lng'] = pin.lng;
  p['area'] = pin.area;
  if (pin.full.isNotEmpty) p['adHint'] = pin.full;
  profPut(p);
  AppState.I.ping();
}

class MapPickScreen extends StatefulWidget {
  final LatLng? at;
  final double acc;
  final MapPin? current;
  const MapPickScreen({super.key, this.at, this.acc = 0, this.current});
  @override
  State<MapPickScreen> createState() => _MapPickScreenState();
}

class _MapPickScreenState extends State<MapPickScreen> {
  final _mc = MapController();
  late LatLng _center;
  LatLng? _accAt;
  double _acc = 0;
  bool _accDone = false;
  bool _dragged = false;
  bool _sat = Store.str(K.mapSat) == '1';
  String _title = '⏳ இடத்தைக் கண்டறிகிறது...', _full = '', _area = '';
  Timer? _geoT, _gpsT;
  int _seq = 0;
  StreamSubscription<Position>? _watch;
  Svc _svc = const Svc(true);
  bool _ready = false;

  Shop? get _shop {
    final s = AppState.I;
    return s.shopById(s.cartShopId ?? s.activeShop);
  }

  @override
  void initState() {
    super.initState();
    _center = widget.at ?? mapStartPos(pin: widget.current);
    if (widget.at != null && widget.acc > 0) {
      _accAt = widget.at;
      _acc = widget.acc;
      _accDone = true;
    }
    final hasPin = widget.current != null || AppState.I.profRaw()['lat'] != null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moved();
      if (widget.at == null && !hasPin) _locate(quiet: true);
    });
  }

  @override
  void dispose() {
    _geoT?.cancel();
    _gpsT?.cancel();
    _watch?.cancel();
    super.dispose();
  }

  void _moved() {
    final v = _shop != null ? svcCheck(_shop!, _center.latitude, _center.longitude) : const Svc(true);
    setState(() {
      _svc = v;
      _title = '⏳ இடத்தைக் கண்டறிகிறது...';
      _full = '';
      _ready = false;
    });
    _geoT?.cancel();
    final seq = ++_seq;
    _geoT = Timer(const Duration(milliseconds: 650), () async {
      try {
        final g = await Geo.reverse(_center.latitude, _center.longitude);
        if (!mounted || seq != _seq) return;
        setState(() {
          _area = g['area']!;
          _full = g['full']!;
          _title = '📍 ${g['title']}';
          _ready = true;
        });
      } catch (_) {
        if (mounted && seq == _seq) {
          setState(() {
            _title = '📍 குறிக்கப்பட்ட இடம்';
            _ready = true;
          });
        }
      }
    });
  }

  void _stop() {
    _watch?.cancel();
    _watch = null;
    _gpsT?.cancel();
  }

  // "என்னைக் கண்டுபிடி": இன்னும் துல்லியமான fix வரும் வரை பின்தொடரும்
  Future<void> _locate({bool quiet = false}) async {
    final e = await Gps.ensure();
    if (e != null) {
      if (!quiet || e == 1) toast(e == 1 ? '📍 இட அனுமதி இல்லை — phone settings-ல் Location அனுமதியுங்கள்' : '📍 Location OFF-ஆக உள்ளது — ON செய்து மீண்டும் முயலுங்கள்');
      return;
    }
    if (!quiet) toast('📍 உங்கள் இடத்தைக் கண்டறிகிறது...');
    _stop();
    _dragged = false;
    Position? best;
    final t0 = DateTime.now();
    void finish() {
      _stop();
      if (best != null) {
        setState(() => _accDone = true);
        if (best!.accuracy > 500) toast('📍 இடம் துல்லியமாக இல்லை (±${best!.accuracy.round()} மீ). Settings → Location → "Precise location" ON செய்யுங்கள்');
      } else if (!quiet) {
        toast('📍 இடம் கிடைக்கவில்லை — Location ON செய்து மீண்டும் முயலுங்கள், அல்லது வரைபடத்தை கையால் நகர்த்துங்கள்');
      }
    }

    _watch = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 0)).listen((p) {
      final acc = p.accuracy > 0 ? p.accuracy : 999.0;
      if (best != null && acc >= best!.accuracy) return;
      best = p;
      AppState.I.setUserLoc(p.latitude, p.longitude);
      if (!mounted) return;
      setState(() {
        _accAt = LatLng(p.latitude, p.longitude);
        _acc = acc;
        _accDone = false;
      });
      if (!_dragged) {
        try {
          final z = _mc.camera.zoom < 18 ? (acc <= 40 ? 19.0 : 18.0) : _mc.camera.zoom;
          _mc.move(LatLng(p.latitude, p.longitude), z);
        } catch (_) {}
        _center = LatLng(p.latitude, p.longitude);
        _moved();
      }
      if (acc <= 12 || (acc <= 25 && DateTime.now().difference(t0).inSeconds > 5)) finish();
    }, onError: (_) {
      if (best == null) finish();
    });
    _gpsT = Timer(const Duration(seconds: 20), finish);
  }

  void _toggleSat() {
    setState(() => _sat = !_sat);
    Store.setStr(K.mapSat, _sat ? '1' : '0');
  }

  @override
  Widget build(BuildContext context) {
    final sh = _shop;
    final mq = MediaQuery.of(context);
    final accCls = _acc <= 20 ? 'good' : (_acc <= 60 ? 'mid' : 'bad');
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: P.bg,
        body: Stack(children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mc,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: widget.at != null || widget.current != null ? 18 : 17,
                maxZoom: 20,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                onPositionChanged: (cam, hasGesture) {
                  if (hasGesture) _dragged = true;
                  if ((cam.center.latitude - _center.latitude).abs() < 1e-7 && (cam.center.longitude - _center.longitude).abs() < 1e-7) return;
                  _center = cam.center;
                  Future.microtask(() {
                    if (mounted) _moved();
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _sat
                      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.chittai.customer',
                  maxNativeZoom: 19,
                  maxZoom: 20,
                ),
                if (_accAt != null && _acc > 0)
                  CircleLayer(circles: [
                    CircleMarker(
                      point: _accAt!,
                      radius: _acc > 300 ? 300.0 : _acc,
                      useRadiusInMeter: true,
                      color: const Color(0x261A73E8),
                      borderColor: const Color(0x801A73E8),
                      borderStrokeWidth: 1,
                    ),
                  ]),
              ],
            ),
          ),
          // நடுவில் நிலையான pin
          const IgnorePointer(
            child: Center(
              child: Padding(padding: EdgeInsets.only(bottom: 44), child: Text('📍', style: TextStyle(fontSize: 42))),
            ),
          ),
          Positioned(
            top: mq.padding.top + 8,
            left: 10,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(tooltip: 'பின்செல்', icon: const Icon(Icons.arrow_back, color: Color(0xFF1C2420)), onPressed: () => Navigator.of(context).pop()),
            ),
          ),
          Positioned(
            top: mq.padding.top + 8,
            left: 62,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: const Color(0xE6FFFFFF), borderRadius: BorderRadius.circular(14)),
              child: Text('வரைபடத்தை நகர்த்தி, pin-ஐ உங்கள் வீட்டின் மேல் வையுங்கள்', style: ts(12.5, w: w7, c: const Color(0xFF1C2420))),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(children: [
                  _chipBtn(Icons.layers_outlined, _sat ? 'வரைபடம்' : 'செயற்கைக்கோள்', _toggleSat, on: _sat),
                  const Spacer(),
                  _chipBtn(Icons.my_location, 'என்னைக் கண்டுபிடி', () => _locate()),
                ]),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + mq.padding.bottom),
                decoration: BoxDecoration(
                  color: P.card,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 20, offset: Offset(0, -4))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  Text('டெலிவரி இடம்', style: ts(12, w: w7, c: P.mu)),
                  const SizedBox(height: 4),
                  Text(_title, style: ts(16.5, w: w8)),
                  if (_full.isNotEmpty && '📍 $_full' != _title) Text(_full, style: ts(12.5, c: P.mu2, h: 1.4)),
                  if (_acc > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: accCls == 'good' ? const Color(0xFFE8F7EE) : (accCls == 'mid' ? const Color(0xFFFFF7E6) : const Color(0xFFFEE2E2)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${accCls == 'good' ? '✅' : '📶'} GPS துல்லியம் ± ${_acc.round()} மீ${_accDone ? '' : '  ⏳ இன்னும் சரிசெய்கிறது...'}', style: ts(12.5, w: w8, c: const Color(0xFF1C2420))),
                        if (_accDone && accCls != 'good')
                          Text('வீட்டுக்கு வெளியே / ஜன்னல் அருகில் வந்து மீண்டும் "என்னைக் கண்டுபிடி" அழுத்துங்கள். அல்லது pin-ஐ கையால் உங்கள் வீட்டின் மேல் நகர்த்துங்கள்.',
                              style: ts(12, c: const Color(0xFF475569), h: 1.4)),
                      ]),
                    ),
                  if (!_svc.ok)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('⚠️ ${_svc.msg}', style: ts(12.5, w: w8, c: const Color(0xFFB91C1C))),
                        GestureDetector(
                          onTap: () => waHelp('வணக்கம், என் இடத்துக்கு (${(_svc.km ?? 0).toStringAsFixed(1)} km) டெலிவரி செய்ய முடியுமா?'),
                          child: Padding(padding: const EdgeInsets.only(top: 4), child: Text('💬 WhatsApp-ல் கேளுங்கள்', style: ts(13, w: w8, c: P.g2, deco: TextDecoration.underline))),
                        ),
                      ]),
                    )
                  else if (sh != null && jz(sh.m['delivery_radius_km']) > 0)
                    Padding(padding: const EdgeInsets.only(top: 6), child: Text('✅ ${sh.name} இங்கு டெலிவரி செய்கிறது', style: ts(12.5, w: w8, c: P.g2))),
                  const SizedBox(height: 12),
                  GreenButton('இந்த இடத்தை உறுதி செய்', onTap: _svc.ok ? _confirm : null),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => openUrl('https://www.openstreetmap.org/copyright'),
                    child: Text(_sat ? '© Esri · © OpenStreetMap' : '© OpenStreetMap', textAlign: TextAlign.center, style: ts(12, c: P.mu)),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  void _confirm() {
    final pin = MapPin(double.parse(_center.latitude.toStringAsFixed(6)), double.parse(_center.longitude.toStringAsFixed(6)), _ready ? _area : '', _ready ? _full : '');
    AppState.I.setUserLoc(pin.lat, pin.lng);
    Navigator.of(context).pop(pin);
  }

  Widget _chipBtn(IconData ic, String l, VoidCallback f, {bool on = false}) => GestureDetector(
        onTap: f,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: on ? AppColors.brand : Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ic, size: 19, color: on ? Colors.white : AppColors.primaryDark),
            const SizedBox(width: 6),
            Text(l, style: ts(13, w: w8, c: on ? Colors.white : const Color(0xFF1C2420))),
          ]),
        ),
      );
}

// ═══ "டெலிவரி இடம் எங்கே?" ═══
Future<void> showLocationSheet() async {
  final c = Nav.ctx;
  if (c == null) return;
  await showModalBottomSheet<void>(
    context: c,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LocSheet(),
  );
}

class _LocSheet extends StatefulWidget {
  const _LocSheet();
  @override
  State<_LocSheet> createState() => _LocSheetState();
}

class _LocSheetState extends State<_LocSheet> {
  Timer? _t;
  int _seq = 0;
  List<Map<String, dynamic>>? _items = [];
  bool _wait = false, _gps = false;
  String _q = '';

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _type(String v) {
    _t?.cancel();
    _q = v.trim();
    if (_q.length < 3) {
      setState(() {
        _items = [];
        _wait = false;
      });
      return;
    }
    setState(() => _wait = true);
    final seq = ++_seq;
    _t = Timer(const Duration(milliseconds: 600), () async {
      final c = mapStartPos();
      final r = await Geo.search(_q, c.latitude, c.longitude);
      if (!mounted || seq != _seq) return;
      setState(() {
        _items = r;
        _wait = false;
      });
    });
  }

  Future<void> _open(LatLng at, {double acc = 0}) async {
    final pin = await openMapPick(at: at, acc: acc);
    if (pin == null || !mounted) return;
    savePinToProfile(pin);
    Navigator.of(context).pop();
    toast('✅ டெலிவரி இடம் சேமிக்கப்பட்டது');
  }

  Future<void> _useGps() async {
    setState(() => _gps = true);
    final p = await Gps.once();
    if (!mounted) return;
    setState(() => _gps = false);
    if (p == null) {
      toast(AppState.I.locState == 'denied' ? '📍 இட அனுமதி இல்லை — பகுதியைத் தேடுங்கள் அல்லது phone settings-ல் அனுமதியுங்கள்' : '📍 இடம் கிடைக்கவில்லை — பகுதியைத் தேடுங்கள்');
      return;
    }
    _open(LatLng(p.latitude, p.longitude), acc: p.accuracy);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppState.I.profRaw();
    final mq = MediaQuery.of(context);
    final savedTxt = js(p['ad']).isNotEmpty ? js(p['ad']) : (js(p['adHint']).isNotEmpty ? js(p['adHint']) : js(p['area']));
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * .85),
        decoration: BoxDecoration(color: P.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + mq.padding.bottom),
        child: ListView(shrinkWrap: true, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('டெலிவரி இடம் எங்கே?', style: ts(20, w: w8)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: P.g,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _gps ? null : _useGps,
                  icon: const Icon(Icons.near_me, size: 20),
                  label: Text(_gps ? 'கண்டறிகிறது...' : 'இப்போதைய இடம்', style: ts(14.5, w: w8, c: Colors.white)),
                ),
              ]),
            ),
            Column(children: [
              IconButton(tooltip: 'மூடு', icon: Icon(Icons.close, color: P.mu2), onPressed: () => Navigator.pop(context)),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(color: P.card3, shape: BoxShape.circle),
                child: Icon(Icons.location_on, size: 46, color: P.g),
              ),
            ]),
          ]),
          const SizedBox(height: 16),
          TextField(
            onChanged: _type,
            textInputAction: TextInputAction.search,
            style: ts(15, w: w6),
            decoration: InputDecoration(
              hintText: 'பகுதி, தெரு அல்லது முகவரியைத் தேடுங்கள்',
              hintStyle: ts(14, c: P.mu),
              suffixIcon: Icon(Icons.search, color: P.mu2),
              filled: true,
              fillColor: P.card2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: P.inputBd)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: P.inputBd)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: P.g, width: focusW())),
            ),
          ),
          if (_wait) Padding(padding: const EdgeInsets.all(14), child: Text('⏳ தேடுகிறது...', style: ts(13.5, c: P.mu))),
          if (!_wait && _items == null) Padding(padding: const EdgeInsets.all(14), child: Text('⚠️ தேட முடியவில்லை — Internet சரிபார்க்கவும்', style: ts(13.5, c: P.mu))),
          if (!_wait && _items != null && _items!.isEmpty && _q.length >= 3) Padding(padding: const EdgeInsets.all(14), child: Text('கிடைக்கவில்லை — வேறு பெயரில் தேடுங்கள்', style: ts(13.5, c: P.mu))),
          if (!_wait && _items != null)
            for (final it in _items!)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Text('📍', style: TextStyle(fontSize: 20)),
                title: Text(js(it['main']), style: ts(14.5, w: w8)),
                subtitle: js(it['sub']).isNotEmpty ? Text(js(it['sub']), style: ts(12, c: P.mu)) : null,
                onTap: () => _open(LatLng(jz(it['lat']), jz(it['lng']))),
              ),
          if (p['lat'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: InkWell(
                onTap: () => _open(LatLng(jz(p['lat']), jz(p['lng']))),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: P.gc, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    const Text('🏠', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('சேமித்த இடம்', style: ts(14, w: w8)),
                        if (savedTxt.isNotEmpty) Text(savedTxt, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(12, c: P.mu2)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ═══ டெலிவரி விவரம்: mobile, பெயர், வரைபட இடம், பிரித்த முகவரி ═══
Future<bool> showAddressSheet({bool thenOrder = false, double total = 0}) async {
  final c = Nav.ctx;
  if (c == null) return false;
  final r = await showModalBottomSheet<bool>(
    context: c,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddrSheet(thenOrder: thenOrder, total: total),
  );
  return r == true;
}

class _AddrSheet extends StatefulWidget {
  final bool thenOrder;
  final double total;
  const _AddrSheet({required this.thenOrder, required this.total});
  @override
  State<_AddrSheet> createState() => _AddrSheetState();
}

class _AddrSheetState extends State<_AddrSheet> {
  late final Map<String, dynamic> _p = AppState.I.profRaw();
  late final _ph = TextEditingController(text: js(_p['ph']));
  late final _nm = TextEditingController(text: js(_p['nm']));
  final Map<String, TextEditingController> _ad = {};
  final Map<String, String> _err = {};
  MapPin? _pin;

  @override
  void initState() {
    super.initState();
    final pa = adPartsOf(_p);
    if ((pa['village'] ?? '').isEmpty && js(_p['area']).isNotEmpty) pa['village'] = js(_p['area']).split(',')[0].trim();
    for (final f in kAdF) {
      _ad[f.k] = TextEditingController(text: pa[f.k] ?? '');
    }
    if (_p['lat'] != null) _pin = MapPin(jz(_p['lat']), jz(_p['lng']), js(_p['area']));
  }

  @override
  void dispose() {
    _ph.dispose();
    _nm.dispose();
    for (final c in _ad.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _map() async {
    final pin = await openMapPick(current: _pin);
    if (pin != null && mounted) setState(() => _pin = pin);
  }

  void _save() {
    final ph = _ph.text.trim(), nm = _nm.text.trim();
    final a = {for (final f in kAdF) f.k: _ad[f.k]!.text.replaceAll(RegExp(r'\s+'), ' ').trim()};
    final e = <String, String>{};
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(ph)) e['ph'] = ph.isEmpty ? 'மொபைல் எண்ணை உள்ளிடுங்கள்' : 'சரியான 10 இலக்க மொபைல் எண்';
    if (nm.isEmpty) e['nm'] = 'பெயரை உள்ளிடுங்கள்';
    e.addAll(adCheck(a));
    setState(() {
      _err
        ..clear()
        ..addAll(e);
    });
    if (e.isNotEmpty) return;
    final o = <String, dynamic>{'nm': nm, 'ph': ph, 'ad': adCompose(a), 'adp': a};
    final pin = _pin;
    if (pin != null) {
      o['lat'] = pin.lat;
      o['lng'] = pin.lng;
      o['area'] = pin.area;
    }
    profPut(o);
    AppState.I.ping();
    Navigator.pop(context, true);
    if (!widget.thenOrder) toast('✅ சேமிக்கப்பட்டது');
  }

  // focus விட்டதும் அந்த ஒரு புலத்தை மட்டும் சரிபார் (_save-ன் அதே விதிகள்)
  void _checkOne(String key) {
    String? m;
    if (key == 'ph') {
      final ph = _ph.text.trim();
      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(ph)) m = ph.isEmpty ? 'மொபைல் எண்ணை உள்ளிடுங்கள்' : 'சரியான 10 இலக்க மொபைல் எண்';
    } else if (key == 'nm') {
      if (_nm.text.trim().isEmpty) m = 'பெயரை உள்ளிடுங்கள்';
    } else if (_ad.containsKey(key)) {
      final a = {for (final f in kAdF) f.k: _ad[f.k]!.text.replaceAll(RegExp(r'\s+'), ' ').trim()};
      m = adCheck(a)[key];
    }
    if (!mounted) return;
    setState(() {
      if (m == null) {
        _err.remove(key);
      } else {
        _err[key] = m;
      }
    });
  }

  Widget _field(String label, TextEditingController c, String key, {String hint = '', bool req = true, bool numOnly = false, int? max, String? prefix}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text.rich(TextSpan(style: ts(13, w: w8, c: P.mu2), children: [
        TextSpan(text: label),
        req ? const TextSpan(text: ' *', style: TextStyle(color: Color(0xFFDC2626))) : TextSpan(text: ' (விருப்பம்)', style: ts(12, c: P.mu)),
      ])),
      const SizedBox(height: 5),
      Focus(
        onFocusChange: (f) {
          if (!f) _checkOne(key);
        },
        child: TextField(
        controller: c,
        keyboardType: numOnly ? TextInputType.number : TextInputType.text,
        inputFormatters: [if (numOnly) FilteringTextInputFormatter.digitsOnly, if (max != null) LengthLimitingTextInputFormatter(max)],
        onChanged: (_) => setState(() => _err.remove(key)),
        style: ts(15, w: w6),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: ts(14, c: P.mu),
          prefixIcon: prefix != null ? Padding(padding: const EdgeInsets.only(left: 12, right: 8), child: Text(prefix, style: ts(15, w: w8))) : null,
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          isDense: true,
          filled: true,
          fillColor: P.card2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: P.inputBd)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _err.containsKey(key) ? const Color(0xFFDC2626) : P.inputBd)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: P.g, width: focusW())),
          suffixIcon: key == 'ph' && RegExp(r'^[6-9]\d{9}$').hasMatch(c.text.trim()) ? const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20) : null,
        ),
      )),
      if (_err[key] != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text('⚠️ ${_err[key]}', style: ts(12.5, w: w7, c: const Color(0xFFDC2626)))),
      const SizedBox(height: 11),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final had = js(_p['nm']).isNotEmpty;
    AdField f(String k) => kAdF.firstWhere((x) => x.k == k);
    Widget adf(String k) {
      final x = f(k);
      return _field(x.l, _ad[k]!, k, hint: x.ph, req: x.req, numOnly: x.num, max: x.num ? 6 : 80);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * .92),
        decoration: BoxDecoration(color: P.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: ListView(shrinkWrap: true, padding: EdgeInsets.fromLTRB(18, 10, 18, 16 + mq.padding.bottom), children: [
          Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: P.bd, borderRadius: BorderRadius.circular(3)))),
          const SizedBox(height: 12),
          Text(had ? 'டெலிவரி விவரம்' : 'கிட்டத்தட்ட முடிந்தது! 🎉', style: ts(20, w: w8)),
          Text(had ? 'மாற்றி சேமியுங்கள்' : 'ஒருமுறை மட்டும் — அடுத்த முறை கேட்க மாட்டோம்', style: ts(13, c: P.mu)),
          const SizedBox(height: 14),
          _field('மொபைல் எண்', _ph, 'ph', hint: '98765 43210', numOnly: true, max: 10, prefix: '🇮🇳 +91'),
          _field('உங்கள் பெயர் (பார்சலில் எழுதப்படும்)', _nm, 'nm', hint: 'உதா: ரவி'),
          Text('டெலிவரி இடம்', style: ts(13, w: w8, c: P.mu2)),
          const SizedBox(height: 5),
          InkWell(
            onTap: _map,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _pin != null ? P.gc : const Color(0xFFFFF7E6),
                border: Border.all(color: _pin != null ? P.bd : const Color(0xFFF6DFB5)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Text(_pin != null ? '📌' : '🗺️', style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_pin != null ? (_pin!.area.isNotEmpty ? _pin!.area : 'இடம் குறிக்கப்பட்டது') : 'வரைபடத்தில் குறியுங்கள்', style: ts(14, w: w8)),
                    Text(_pin != null ? 'வரைபடத்தில் குறிக்கப்பட்டது' : 'Delivery நபர் வீட்டை எளிதில் கண்டுபிடிப்பார்', style: ts(12, c: P.mu2)),
                  ]),
                ),
                Text(_pin != null ? 'மாற்று' : '›', style: ts(13.5, w: w8, c: P.g2)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: adf('door')),
            const SizedBox(width: 10),
            Expanded(child: adf('pin')),
          ]),
          adf('street'),
          adf('village'),
          adf('land'),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('🛵 "அடையாளம்" சரியாக இருந்தால் டெலிவரி நபர் வீட்டை எளிதில் கண்டுபிடிப்பார்.', style: ts(12, c: P.mu, h: 1.5)),
          ),
          GreenButton(widget.thenOrder && widget.total > 0 ? 'சேமித்து ஆர்டர் செய் · ₹${rupee(widget.total)}' : 'சேமி', onTap: _save),
        ]),
      ),
    );
  }
}
