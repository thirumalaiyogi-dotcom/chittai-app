// சிட்டை — ஆர்டர் தரவு: இந்த phone-ல் சேமித்த ஆர்டர்கள் + server நிலை (orders_track), ஆர்டர் செய்தல் (place_order)
import 'dart:async';
import 'dart:math' as math;

import 'api.dart';
import 'models.dart';
import 'state.dart';
import 'store.dart';
import 'util.dart';

class OrdItem {
  final String n, w;
  final int q;
  final double t;
  final double? up;
  final dynamic pid;
  final bool na; // கடையில் இல்லை
  OrdItem({required this.n, required this.w, required this.q, required this.t, this.up, this.pid, this.na = false});
}

class Ord {
  String? id; // server id (uuid)
  String no = '';
  int ts = 0;
  String date = '', sched = '', shop = '', shopPhone = '';
  String? shopId;
  List<OrdItem> its = [];
  double tot = 0;
  double? sub;
  double del = 0;
  String status = 'LOCAL_ONLY';
  String nm = '', ph = '', ad = '', nt = '';
  bool cloud = false;
  String otp = '', cr = '', pm = '';
  String? dp;
  String dpName = '', dpPhone = '';
  String? oid;
  Map<String, String?> t = {};
  bool revEdit = false;
}

const kOrdStatusLabel = {
  'ORDER_RECEIVED': '🆕 புதிய ஆர்டர்',
  'SHOP_ACCEPTED': '✅ உறுதி செய்யப்பட்டது — கடை பார்சல் செய்கிறது',
  'PREPARING': '👨‍🍳 தயார் செய்யப்படுகிறது',
  'READY_FOR_PICKUP': '📦 பார்சல் ரெடி — delivery வருகிறார்',
  'DELIVERY_ASSIGNED': '🚴 டெலிவரி ஒதுக்கப்பட்டது',
  'OUT_FOR_DELIVERY': '🚚 டெலிவரிக்கு புறப்பட்டது',
  'DELIVERED': '🎉 டெலிவரி முடிந்தது',
  'CANCELLED': '❌ ரத்து செய்யப்பட்டது',
};
// வாடிக்கையாளர் பட்டியல் chip: [உரை, நிறம், ஐகான்]
const kCoSt = {
  'ORDER_RECEIVED': ['உறுதி செய்யப்படுகிறது', 'w', '🕒'],
  'SHOP_ACCEPTED': ['தயாராகிறது', 'w', '📦'],
  'PREPARING': ['தயாராகிறது', 'w', '📦'],
  'READY_FOR_PICKUP': ['பார்சல் ரெடி', 'b', '🛍️'],
  'DELIVERY_ASSIGNED': ['பார்சல் ரெடி', 'b', '🛍️'],
  'OUT_FOR_DELIVERY': ['வந்துகொண்டிருக்கிறது', 'b', '🛵'],
  'DELIVERED': ['டெலிவரி ஆனது', 'g', '✓'],
  'CANCELLED': ['ரத்து செய்யப்பட்டது', 'r', '✕'],
};
const kCustCancel = ['ORDER_RECEIVED', 'SHOP_ACCEPTED']; // கடை தயாரிக்கத் தொடங்கும் வரை மட்டும்

bool coActive(Ord o) => o.cloud && o.status != 'DELIVERED' && o.status != 'CANCELLED';

String fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}, ${hm12(d)}';

String coDate(Ord o) {
  if (o.ts == 0) return o.date;
  final d = DateTime.fromMillisecondsSinceEpoch(o.ts);
  final n = DateTime.now();
  bool same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  final y = n.subtract(const Duration(days: 1));
  final day = same(d, n) ? 'இன்று' : (same(d, y) ? 'நேற்று' : '${d.day} ${kTaMonthsShort[d.month - 1]}');
  return '$day · ${tTime('${d.hour}:${d.minute}')}';
}

String uuidV4() {
  final r = math.Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  final s = List.generate(16, h).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

class Orders {
  static AppState get S => AppState.I;
  static List<dynamic> cache = []; // கடைசியாக server தந்த ஆர்டர்கள்
  static Future<List<dynamic>?>? _inflight;
  static int _at = 0;

  static List<Map<String, dynamic>> local() => S.ordLocal();
  static void saveLocal(List<Map<String, dynamic>> l) => Store.setJson(K.ords, l);

  static Set<String> hidden() {
    final a = Store.json(K.ordHidden);
    return a is List ? a.map((x) => x.toString()).toSet() : <String>{};
  }

  static void hide(List<Ord> l) {
    final h = hidden();
    for (final o in l) {
      if (o.no.isNotEmpty) h.add(o.no);
      if (o.id != null) h.add(o.id!);
    }
    final all = h.toList();
    Store.setJson(K.ordHidden, all.length > 500 ? all.sublist(all.length - 500) : all);
  }

  static void invalidate() {
    _at = 0;
    _inflight = null;
  }

  // sbGetOrders: id + அதே mobile எண் சேர்ந்து மட்டுமே (orders_track)
  static Future<List<dynamic>?> fetch({bool force = false}) {
    if (force) invalidate();
    if (_inflight != null) return _inflight!;
    if (_at > 0 && DateTime.now().millisecondsSinceEpoch - _at < 8000) return Future.value(cache);
    _inflight = _fetchRaw().then((r) {
      _inflight = null;
      _at = r != null ? DateTime.now().millisecondsSinceEpoch : 0;
      return r;
    });
    return _inflight!;
  }

  static Future<List<dynamic>?> _fetchRaw() async {
    final pp = S.profRaw();
    final uuid = RegExp(r'^[0-9a-f-]{36}$', caseSensitive: false);
    final list = local()
        .where((e) => uuid.hasMatch(js(e['oid'])))
        .take(50)
        .map((e) => {'id': js(e['oid']), 'ph': js(e['ph']).isNotEmpty ? js(e['ph']) : js(pp['ph'])})
        .toList();
    if (list.isEmpty) {
      cache = [];
      return [];
    }
    var r = await Api.rpc('orders_track', {'p_list': list});
    var track = true;
    if (r.status == 404) {
      track = false;
      r = await Api.rpc('orders_by_ids', {'p_ids': list.map((x) => x['id']).toList()});
    }
    if (!r.ok) return null;
    final rows = r.data is List ? r.data as List : <dynamic>[];
    // server-ல் இல்லாத (நீக்கிய சோதனை) ஆர்டர்களை இந்த phone-லிருந்தும் நீக்கு
    if (track) {
      final got = rows.whereType<Map>().map((x) => js(x['id'])).toSet();
      final sent = list.map((x) => x['id']!).toSet();
      final all = local();
      final keep = all.where((e) => !(js(e['oid']).isNotEmpty && sent.contains(js(e['oid'])) && !got.contains(js(e['oid'])))).toList();
      if (keep.length != all.length) saveLocal(keep);
    }
    cache = rows;
    return rows;
  }

  // cloud + இந்த phone-ன் ஆர்டர்கள் → ஒரே பட்டியல்
  static List<Ord> build(List<dynamic>? rows) {
    final hid = hidden();
    final loc = local().where((o) => !hid.contains(js(o['oNo'])) && !(js(o['oid']).isNotEmpty && hid.contains(js(o['oid'])))).toList();
    final nos = loc.map((o) => js(o['oNo'])).toSet(), phs = loc.map((o) => js(o['ph'])).toSet();
    final oids = loc.where((o) => js(o['oid']).isNotEmpty).map((o) => js(o['oid'])).toSet();
    final out = <Ord>[];
    final seen = <String>{};
    for (final r0 in rows ?? const []) {
      if (r0 is! Map) continue;
      final o = Map<String, dynamic>.from(r0);
      final no = js(o['order_number']), id = js(o['id']);
      if (!(nos.contains(no) || phs.contains(js(o['customer_phone'])) || oids.contains(id))) continue;
      if (hid.contains(no) || (id.isNotEmpty && hid.contains(id))) continue;
      final l = loc.where((x) => js(x['oNo']) == no || (js(x['oid']).isNotEmpty && js(x['oid']) == id)).first0 ?? const <String, dynamic>{};
      final shopId = js(o['shop_id']).isNotEmpty ? js(o['shop_id']) : (js(l['shopId']).isNotEmpty ? js(l['shopId']) : null);
      final sh = shopId != null ? S.shopById(shopId) : null;
      final x = Ord()
        ..id = id.isEmpty ? null : id
        ..no = no
        ..ts = DateTime.tryParse(js(o['created_at']))?.millisecondsSinceEpoch ?? 0
        ..sched = js(o['scheduled_slot']).isNotEmpty ? js(o['scheduled_slot']) : js(l['sched'])
        ..shop = js(o['shop_name']).isNotEmpty ? js(o['shop_name']) : (js(l['shopName']).isNotEmpty ? js(l['shopName']) : (sh?.name ?? ''))
        ..shopId = shopId
        ..shopPhone = sh?.phone ?? ''
        ..tot = jz(o['total'])
        ..status = js(o['order_status'])
        ..nm = js(o['customer_name'])
        ..ph = js(o['customer_phone'])
        ..ad = js(o['customer_address'])
        ..nt = js(o['customer_note'])
        ..cloud = true
        ..otp = js(o['delivery_otp'])
        ..cr = js(o['cancel_reason'])
        ..pm = js(o['pay_mode'])
        ..dp = o['delivery_partner_id']?.toString()
        ..dpName = o['delivery_partner'] is Map ? js((o['delivery_partner'] as Map)['name']) : ''
        ..dpPhone = o['delivery_partner'] is Map ? js((o['delivery_partner'] as Map)['phone']) : ''
        ..sub = o['subtotal'] != null ? jz(o['subtotal']) : (l['sub'] != null ? jz(l['sub']) : null)
        ..del = o['delivery_fee'] != null ? jz(o['delivery_fee']) : jz(l['del'])
        ..oid = id.isEmpty ? null : id
        ..t = {
          'c': o['created_at']?.toString(),
          'a': o['approved_at']?.toString(),
          'r': o['ready_at']?.toString(),
          'p': o['picked_at']?.toString(),
          'd': o['delivered_at']?.toString(),
          'x': js(o['order_status']) == 'CANCELLED' ? o['updated_at']?.toString() : null,
        };
      x.date = x.ts > 0 ? fmtDate(DateTime.fromMillisecondsSinceEpoch(x.ts)) : '';
      final items = o['order_items'];
      if (items is List) {
        x.its = items.whereType<Map>().map((i) {
          final q = jz(i['quantity']).toInt();
          final tp = jz(i['total_price']);
          return OrdItem(
            n: js(i['product_name']),
            w: js(i['pack_size']),
            q: q,
            t: tp,
            up: i['unit_price'] != null ? jz(i['unit_price']) : (q > 0 ? round2(tp / q) : null),
            pid: i['product_id'],
            na: i['unavailable'] == true,
          );
        }).toList();
      }
      seen.add(no);
      if (id.isNotEmpty) seen.add(id);
      out.add(x);
    }
    for (final o in loc) {
      final no = js(o['oNo']), oid = js(o['oid']);
      if (seen.contains(no) || (oid.isNotEmpty && seen.contains(oid))) continue;
      final shopId = js(o['shopId']).isNotEmpty ? js(o['shopId']) : null;
      final sh = shopId != null ? S.shopById(shopId) : null;
      final its = o['its'] is List ? (o['its'] as List).whereType<Map>() : const <Map>[];
      out.add(Ord()
        ..no = no
        ..ts = jz(o['ts']).toInt()
        ..date = js(o['date'])
        ..shop = js(o['shopName']).isNotEmpty ? js(o['shopName']) : (sh?.name ?? '')
        ..shopId = shopId
        ..shopPhone = sh?.phone ?? ''
        ..its = its.map((i) => OrdItem(n: js(i['n']), w: js(i['w']), q: jz(i['q']).toInt(), t: jz(i['t']), up: i['up'] != null ? jz(i['up']) : null, pid: i['pid'])).toList()
        ..sub = o['sub'] != null ? jz(o['sub']) : null
        ..del = jz(o['del'])
        ..tot = jz(o['tot'])
        ..status = 'LOCAL_ONLY'
        ..nm = js(o['nm'])
        ..ph = js(o['ph'])
        ..ad = js(o['ad'])
        ..oid = oid.isEmpty ? null : oid
        ..sched = js(o['sched']));
    }
    out.sort((a, b) => b.ts.compareTo(a.ts));
    return out;
  }

  static int pendingCount(List<dynamic>? rows) => build(rows).where((o) => o.status == 'ORDER_RECEIVED').length;
}

// ═══ ஆர்டர் செய்தல் (விலை, டெலிவரி, மொத்தம், ஆர்டர் எண் எல்லாம் server-லிருந்து) ═══
class PlaceResult {
  final bool ok;
  final String code, msg;
  final Map<String, dynamic> data;
  PlaceResult(this.ok, this.code, this.msg, this.data);
}

Future<PlaceResult> placeOrderRpc(Map<String, dynamic> params) async {
  final fn = params['p_sched_at'] != null ? 'place_order_sched' : 'place_order';
  final r = await Api.rpc(fn, params, timeout: const Duration(seconds: 20));
  if (r.status == 0) return PlaceResult(false, 'NET', '📴 Network பிரச்சனை — இணையம் சரிபார்த்து மீண்டும் முயற்சிக்கவும்', {});
  if (!r.ok) {
    if (r.status == 404) {
      return PlaceResult(false, 'NO_RPC', fn == 'place_order_sched' ? 'முன்பதிவு வசதி இன்னும் அமைக்கப்படவில்லை (schedule.sql)' : 'Server function இன்னும் அமைக்கப்படவில்லை (place_order.sql run செய்யுங்கள்)', {});
    }
    return PlaceResult(false, 'HTTP', 'ஆர்டர் சேமிக்க முடியவில்லை (HTTP ${r.status}) — மீண்டும் முயற்சிக்கவும்', {});
  }
  if (r.data is! Map) return PlaceResult(false, 'EMPTY', 'Server பதில் இல்லை — மீண்டும் முயற்சிக்கவும்', {});
  final d = Map<String, dynamic>.from(r.data as Map);
  return PlaceResult(d['ok'] == true, js(d['code']), js(d['msg']), d);
}

// ═══ 📅 முன்பதிவு: இன்று முதல் 7 நாள், கடை நேரத்துக்குள் 2 மணி நேர slot, குறைந்தது 45 நிமிடம் முன்னதாக ═══
class SchSlot {
  final String at, lb;
  SchSlot(this.at, this.lb);
}

class SchDay {
  final String chip, sub, full;
  final List<SchSlot> slots;
  SchDay(this.chip, this.sub, this.full, this.slots);
}

String _schT(int m) {
  final h = m ~/ 60, mi = m % 60, h12 = ((h + 11) % 12) + 1;
  return '$h12${mi > 0 ? ':${mi.toString().padLeft(2, '0')}' : ''}';
}

String _schPer(int m) {
  final h = m / 60;
  return h < 12 ? 'காலை' : (h < 16 ? 'மதியம்' : (h < 19 ? 'மாலை' : 'இரவு'));
}

List<SchDay> schDays(Shop? shop) {
  var a = hmToMin(shop?.openingTime), b = hmToMin(shop?.closingTime);
  if (shop == null || shop.openingTime.isEmpty || shop.closingTime.isEmpty || a == null || b == null || a == b) {
    a = 7 * 60;
    b = 21 * 60;
  }
  if (b < a) b = 24 * 60; // நள்ளிரவு தாண்டி மூடும் கடை: நள்ளிரவு வரை
  final now = DateTime.now();
  final out = <SchDay>[];
  for (var d = 0; d < 7; d++) {
    final base = DateTime(now.year, now.month, now.day + d);
    final slots = <SchSlot>[];
    for (var m = ((a / 60).ceil()) * 60; m < b; m += 120) {
      final e = math.min(m + 120, b);
      if (e - m < 60) continue;
      final at = base.add(Duration(minutes: m));
      if (at.difference(now).inMinutes < 45) continue;
      slots.add(SchSlot(at.toUtc().toIso8601String(), '${_schPer(m)} ${_schT(m)}–${_schT(e)}'));
    }
    if (slots.isNotEmpty) {
      final dl = d == 0 ? 'இன்று' : (d == 1 ? 'நாளை' : kTaWeekdays[base.weekday % 7]);
      out.add(SchDay(dl, '${base.day} ${kTaMonthsShort[base.month - 1]}', '${d < 2 ? '$dl · ' : ''}${kTaWeekdays[base.weekday % 7]} ${base.day} ${kTaMonthsShort[base.month - 1]}', slots));
    }
  }
  return out;
}

// கடையின் டெலிவரி வட்டம் (place_order-ன் அதே விதி)
class SvcCheck {
  final bool ok;
  final double? km;
  final String msg;
  SvcCheck(this.ok, [this.km, this.msg = '']);
}

SvcCheck svcCheck(Shop shop, double? lat, double? lng) {
  final rad = jz(shop.m['delivery_radius_km']);
  if (!(rad > 0) || shop.lat == null || shop.lng == null || lat == null || lng == null) return SvcCheck(true);
  final km = kmBetween(shop.lat!, shop.lng!, lat, lng);
  return km <= rad ? SvcCheck(true, km) : SvcCheck(false, km, '${shop.name} ${rupee(rad)} km வரை மட்டுமே டெலிவரி — நீங்கள் ${km.toStringAsFixed(1)} km தொலைவில்');
}

// ═══ 🏠 பிரித்த முகவரி → ஒரே வரி ═══
class AdField {
  final String k, l, ph;
  final bool req, half, num;
  const AdField(this.k, this.l, this.ph, {this.req = false, this.half = false, this.num = false});
}

const kAdFields = [
  AdField('door', 'வீட்டு எண் / பெயர்', 'உதா: 12/3', req: true, half: true),
  AdField('pin', 'பின்கோடு', '627001', half: true, num: true),
  AdField('street', 'தெரு / பகுதி', 'உதா: கீழத் தெரு, 2-வது சந்து', req: true),
  AdField('village', 'ஊர்', 'உதா: பாளையங்கோட்டை', req: true),
  AdField('land', 'அடையாளம் (அருகில் உள்ளது)', 'உதா: பிள்ளையார் கோவில் எதிரே, நீல கேட் வீடு', req: true),
];

Map<String, String> adPartsOf(Map<String, dynamic> p) {
  if (p['adp'] is Map) return (p['adp'] as Map).map((k, v) => MapEntry(k.toString(), js(v)));
  return js(p['ad']).isNotEmpty ? {'street': js(p['ad'])} : {};
}

String adCompose(Map<String, String> a) {
  String t(String k) => (a[k] ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  var s = [t('door'), t('street'), t('village')].where((x) => x.isNotEmpty).join(', ');
  if (t('pin').isNotEmpty) s += ' - ${t('pin')}';
  if (t('land').isNotEmpty) s += ' · அடையாளம்: ${t('land')}';
  return s;
}
