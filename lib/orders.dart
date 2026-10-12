// சிட்டை — ஆர்டர் விதிகள்: ஆர்டர் செய்தல் (place_order), பின்தொடர்தல் (orders_track), ரத்து, மீண்டும் வாங்க, முன்பதிவு நேரங்கள்
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'config.dart';
import 'models.dart';
import 'state.dart';
import 'store.dart';
import 'util.dart';

String uuid4() {
  final r = math.Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  final s = List.generate(16, h).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

final RegExp kUuid = RegExp(r'^[0-9a-f-]{36}$', caseSensitive: false);

// web app-ன் toLocaleString('ta-IN') போல: "12/10/2026, 12:14 PM"
String fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}, ${hm12(d)}';

// ═══ முகவரி: பிரித்த பகுதிகள் → ஒரே வரி (server-க்கு அப்படியே) ═══
class AdField {
  final String k, l, ph;
  final bool req, half, num;
  const AdField(this.k, this.l, this.ph, {this.req = true, this.half = false, this.num = false});
}

const List<AdField> kAdF = [
  AdField('door', 'வீட்டு எண் / பெயர்', 'உதா: 12/3', half: true),
  AdField('pin', 'பின்கோடு', '627001', req: false, half: true, num: true),
  AdField('street', 'தெரு / பகுதி', 'உதா: கீழத் தெரு, 2-வது சந்து'),
  AdField('village', 'ஊர்', 'உதா: பாளையங்கோட்டை'),
  AdField('land', 'அடையாளம் (அருகில் உள்ளது)', 'உதா: பிள்ளையார் கோவில் எதிரே, நீல கேட் வீடு'),
];

Map<String, String> adPartsOf(Map<String, dynamic> p) {
  final a = p['adp'];
  if (a is Map) return a.map((k, v) => MapEntry(k.toString(), js(v)));
  return js(p['ad']).isNotEmpty ? {'street': js(p['ad'])} : {};
}

String adCompose(Map<String, String> a) {
  String t(String k) => (a[k] ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  var s = [t('door'), t('street'), t('village')].where((x) => x.isNotEmpty).join(', ');
  if (t('pin').isNotEmpty) s += ' - ${t('pin')}';
  if (t('land').isNotEmpty) s += ' · அடையாளம்: ${t('land')}';
  return s;
}

// பிழைச் செய்திகள் (field → செய்தி); காலி = சரி
Map<String, String> adCheck(Map<String, String> a) {
  final e = <String, String>{};
  for (final f in kAdF) {
    final v = (a[f.k] ?? '').trim();
    if (f.req && v.isEmpty) {
      e[f.k] = f.k == 'land' ? 'அருகில் உள்ள ஒரு அடையாளத்தைச் சொல்லுங்கள்' : '${f.l} தேவை';
    } else if (f.k == 'pin' && v.isNotEmpty && !RegExp(r'^[1-9]\d{5}$').hasMatch(v)) {
      e[f.k] = '6 இலக்க பின்கோடு';
    }
  }
  return e;
}

void profPut(Map<String, dynamic> o) => Store.setJson(K.profile, o);

// ═══ டெலிவரி பகுதி சோதனை (place_order-ன் அதே விதி) ═══
class Svc {
  final bool ok;
  final double? km;
  final String msg;
  const Svc(this.ok, [this.km, this.msg = '']);
}

Svc svcCheck(Shop shop, double? lat, double? lng) {
  final rad = jz(shop.m['delivery_radius_km']);
  if (!(rad > 0) || shop.lat == null || shop.lng == null || lat == null || lng == null) return const Svc(true);
  final km = kmBetween(shop.lat!, shop.lng!, lat, lng);
  return km <= rad ? Svc(true, km) : Svc(false, km, '${shop.name} ${rupee(rad)} km வரை மட்டுமே டெலிவரி — நீங்கள் ${km.toStringAsFixed(1)} km தொலைவில்');
}

// ═══ 📅 முன்பதிவு: இன்று முதல் 7 நாள், கடை நேரத்துக்குள் 2 மணி நேர slot, குறைந்தது 45 நிமிடம் முன் ═══
class SchSlot {
  final String at, lb;
  const SchSlot(this.at, this.lb);
}

class SchDay {
  final int d;
  final String chip, sub, full;
  final List<SchSlot> slots;
  const SchDay(this.d, this.chip, this.sub, this.full, this.slots);
}

String _schT(int m) {
  final h = m ~/ 60, mi = m % 60, h12 = ((h + 11) % 12) + 1;
  return '$h12${mi > 0 ? ':${mi.toString().padLeft(2, '0')}' : ''}';
}

String _schPer(int m) {
  final h = m / 60;
  return h < 12
      ? 'காலை'
      : h < 16
          ? 'மதியம்'
          : h < 19
              ? 'மாலை'
              : 'இரவு';
}

List<SchDay> schDays(Shop? shop) {
  var a = hmToMin(shop?.openingTime), b = hmToMin(shop?.closingTime);
  if (shop == null || shop.openingTime.isEmpty || shop.closingTime.isEmpty || a == null || b == null || a == b) {
    a = 7 * 60;
    b = 21 * 60;
  }
  if (b < a) b = 24 * 60;
  final now = DateTime.now();
  final out = <SchDay>[];
  for (var d = 0; d < 7; d++) {
    final base = DateTime(now.year, now.month, now.day + d);
    final slots = <SchSlot>[];
    for (var m = (a / 60).ceil() * 60; m < b; m += 120) {
      final e = math.min(m + 120, b);
      if (e - m < 60) continue;
      final at = base.add(Duration(minutes: m));
      if (at.difference(now).inMinutes < 45) continue;
      slots.add(SchSlot(at.toUtc().toIso8601String(), '${_schPer(m)} ${_schT(m)}–${_schT(e)}'));
    }
    if (slots.isNotEmpty) {
      final wd = kTaWeekdays[base.weekday % 7];
      final dl = d == 0
          ? 'இன்று'
          : d == 1
              ? 'நாளை'
              : wd;
      final mo = kTaMonthsShort[base.month - 1];
      out.add(SchDay(d, dl, '${base.day} $mo', '${d < 2 ? '$dl · ' : ''}$wd ${base.day} $mo', slots));
    }
  }
  return out;
}

// ═══ ஆர்டர் காட்சி வடிவம் ═══
class OItem {
  final String n, w;
  final int q;
  final double t;
  final double? up;
  final dynamic pid;
  final bool na;
  OItem(this.n, this.w, this.q, this.t, this.up, this.pid, this.na);
}

class OrderV {
  String? id;
  String no = '';
  int ts = 0;
  String date = '', sched = '', shop = '', shopPhone = '', status = '', nm = '', ph = '', ad = '', nt = '';
  String? shopId;
  List<OItem> its = [];
  double tot = 0, del = 0;
  double? sub;
  bool cloud = false;
  String otp = '', cr = '', pm = '', dpName = '', dpPhone = '';
  String? dp, oid;
  Map<String, String?> t = {};
}

const Map<String, List<String>> kCoSt = {
  'ORDER_RECEIVED': ['உறுதி செய்யப்படுகிறது', 'w', '🕒'],
  'SHOP_ACCEPTED': ['தயாராகிறது', 'w', '📦'],
  'PREPARING': ['தயாராகிறது', 'w', '📦'],
  'READY_FOR_PICKUP': ['பார்சல் ரெடி', 'b', '🛍️'],
  'DELIVERY_ASSIGNED': ['பார்சல் ரெடி', 'b', '🛍️'],
  'OUT_FOR_DELIVERY': ['வந்துகொண்டிருக்கிறது', 'b', '🛵'],
  'DELIVERED': ['டெலிவரி ஆனது', 'g', '✓'],
  'CANCELLED': ['ரத்து செய்யப்பட்டது', 'r', '✕'],
};
const List<String> kCustCancel = ['ORDER_RECEIVED', 'SHOP_ACCEPTED'];

bool coActive(OrderV o) => o.cloud && o.status != 'DELIVERED' && o.status != 'CANCELLED';

class Orders extends ChangeNotifier {
  Orders._();
  static final Orders I = Orders._();
  AppState get S => AppState.I;

  List<Map<String, dynamic>>? cache; // கடைசியாக server தந்தவை
  int _at = 0;
  Future<List<Map<String, dynamic>>?>? _inflight;
  bool lastFail = false;

  List<Map<String, dynamic>> local() => S.ordLocal();

  Set<String> hidden() {
    final a = Store.json(K.ordHidden);
    return a is List ? a.map((x) => js(x)).toSet() : <String>{};
  }

  void hide(List<OrderV> l) {
    final h = hidden();
    for (final o in l) {
      if (o.no.isNotEmpty) h.add(o.no);
      if (o.id != null) h.add(o.id!);
    }
    final all = h.toList();
    Store.setJson(K.ordHidden, all.length > 500 ? all.sublist(all.length - 500) : all);
    notifyListeners();
  }

  // order id + அதே mobile எண் → orders_track
  Future<List<Map<String, dynamic>>?> fetch({bool force = false}) {
    if (_inflight != null) return _inflight!;
    if (!force && cache != null && DateTime.now().millisecondsSinceEpoch - _at < 8000) return Future.value(cache);
    _inflight = _fetchRaw().then((r) {
      _inflight = null;
      if (r != null) {
        _at = DateTime.now().millisecondsSinceEpoch;
        cache = r;
        lastFail = false;
      } else {
        _at = 0;
        lastFail = true;
      }
      notifyListeners();
      return r;
    });
    return _inflight!;
  }

  Future<List<Map<String, dynamic>>?> _fetchRaw() async {
    final pp = S.profRaw();
    final list = local()
        .where((e) => kUuid.hasMatch(js(e['oid'])))
        .take(50)
        .map((e) => {'id': js(e['oid']), 'ph': js(e['ph']).isNotEmpty ? js(e['ph']) : js(pp['ph'])})
        .toList();
    if (list.isEmpty) return <Map<String, dynamic>>[];
    var r = await Api.rpc('orders_track', {'p_list': list});
    var track = true;
    if (r.status == 404) {
      track = false;
      r = await Api.rpc('orders_by_ids', {'p_ids': list.map((x) => x['id']).toList()});
    }
    if (!r.ok || r.data is! List) return null;
    final rows = (r.data as List).whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
    if (track) {
      // server இனி வைத்திருக்காத (நீக்கப்பட்ட சோதனை) ஆர்டர்களை இந்த phone-லிருந்தும் நீக்கு
      final got = rows.map((x) => js(x['id'])).toSet(), sent = list.map((x) => x['id']).toSet();
      final all = local();
      final keep = all.where((e) => !(js(e['oid']).isNotEmpty && sent.contains(js(e['oid'])) && !got.contains(js(e['oid'])))).toList();
      if (keep.length != all.length) Store.setJson(K.ords, keep);
    }
    return rows;
  }

  // cloud வரிகள் + இந்த phone-ன் ஆர்டர்கள் → ஒரே பட்டியல்
  List<OrderV> build([List<Map<String, dynamic>>? rows0]) {
    final rows = rows0 ?? cache ?? const [];
    final hid = hidden();
    final loc = local().where((o) => !hid.contains(js(o['oNo'])) && !(js(o['oid']).isNotEmpty && hid.contains(js(o['oid'])))).toList();
    final nos = loc.map((o) => js(o['oNo'])).toSet(), phs = loc.map((o) => js(o['ph'])).toSet(), oids = loc.where((o) => js(o['oid']).isNotEmpty).map((o) => js(o['oid'])).toSet();
    final out = <OrderV>[];
    final seen = <String>{};
    for (final o in rows) {
      final no = js(o['order_number']), id = js(o['id']);
      if (!(nos.contains(no) || phs.contains(js(o['customer_phone'])) || oids.contains(id))) continue;
      if (hid.contains(no) || (id.isNotEmpty && hid.contains(id))) continue;
      final l = loc.where((x) => js(x['oNo']) == no || (js(x['oid']).isNotEmpty && js(x['oid']) == id)).first0 ?? const <String, dynamic>{};
      final shopId = js(o['shop_id']).isNotEmpty ? js(o['shop_id']) : (js(l['shopId']).isNotEmpty ? js(l['shopId']) : null);
      final sh = shopId != null ? S.shopById(shopId) : null;
      final its = (o['order_items'] is List ? o['order_items'] as List : const [])
          .whereType<Map>()
          .map((i) => OItem(
                js(i['product_name']),
                js(i['pack_size']),
                jz(i['quantity']).toInt(),
                jz(i['total_price']),
                i['unit_price'] != null ? jz(i['unit_price']) : (jz(i['quantity']) > 0 ? round2(jz(i['total_price']) / jz(i['quantity'])) : null),
                i['product_id'],
                i['unavailable'] == true,
              ))
          .toList();
      seen.add(no);
      if (id.isNotEmpty) seen.add(id);
      final created = DateTime.tryParse(js(o['created_at']))?.toLocal() ?? DateTime.now();
      final dp = o['delivery_partner'] is Map ? o['delivery_partner'] as Map : const {};
      final v = OrderV()
        ..id = id.isEmpty ? null : id
        ..no = no
        ..ts = created.millisecondsSinceEpoch
        ..date = fmtDate(created)
        ..sched = js(o['scheduled_slot']).isNotEmpty ? js(o['scheduled_slot']) : js(l['sched'])
        ..shop = js(o['shop_name']).isNotEmpty ? js(o['shop_name']) : (js(l['shopName']).isNotEmpty ? js(l['shopName']) : (sh?.name ?? ''))
        ..shopId = shopId
        ..shopPhone = sh?.phone ?? ''
        ..its = its
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
        ..dp = o['delivery_partner_id'] == null ? null : js(o['delivery_partner_id'])
        ..dpName = js(dp['name'])
        ..dpPhone = js(dp['phone'])
        ..sub = o['subtotal'] != null ? jz(o['subtotal']) : (l['sub'] != null ? jz(l['sub']) : null)
        ..del = o['delivery_fee'] != null ? jz(o['delivery_fee']) : jz(l['del'])
        ..t = {
          'c': js(o['created_at']),
          'a': o['approved_at'] == null ? null : js(o['approved_at']),
          'r': o['ready_at'] == null ? null : js(o['ready_at']),
          'p': o['picked_at'] == null ? null : js(o['picked_at']),
          'd': o['delivered_at'] == null ? null : js(o['delivered_at']),
          'x': js(o['order_status']) == 'CANCELLED' && o['updated_at'] != null ? js(o['updated_at']) : null,
        };
      out.add(v);
    }
    for (final o in loc) {
      final no = js(o['oNo']), oid = js(o['oid']);
      if (seen.contains(no) || (oid.isNotEmpty && seen.contains(oid))) continue;
      final sid = js(o['shopId']).isNotEmpty ? js(o['shopId']) : null;
      final sh = sid != null ? S.shopById(sid) : null;
      final its = (o['its'] is List ? o['its'] as List : const [])
          .whereType<Map>()
          .map((i) => OItem(js(i['n']), js(i['w']), jz(i['q']).toInt(), jz(i['t']), i['up'] != null ? jz(i['up']) : null, i['pid'], false))
          .toList();
      out.add(OrderV()
        ..no = no
        ..ts = jz(o['ts']).toInt()
        ..date = js(o['date'])
        ..shop = js(o['shopName']).isNotEmpty ? js(o['shopName']) : (sh?.name ?? '')
        ..shopId = sid
        ..shopPhone = sh?.phone ?? ''
        ..its = its
        ..sub = o['sub'] != null ? jz(o['sub']) : null
        ..del = jz(o['del'])
        ..tot = jz(o['tot'])
        ..status = 'LOCAL_ONLY'
        ..nm = js(o['nm'])
        ..ph = js(o['ph'])
        ..ad = js(o['ad'])
        ..cloud = false
        ..oid = oid.isEmpty ? null : oid
        ..sched = js(o['sched']));
    }
    out.sort((a, b) => b.ts.compareTo(a.ts));
    return out;
  }

  // கீழ் பட்டை badge: உறுதி செய்யப்படாத ஆர்டர்கள்
  int get badge {
    if (cache == null) return 0;
    return build().where((o) => o.status == 'ORDER_RECEIVED').length;
  }

  void saveLocal(Map<String, dynamic> oe) {
    final ords = local();
    if (!ords.any((x) => js(x['oid']) == js(oe['oid']))) {
      ords.insert(0, oe);
      if (ords.length > 50) ords.removeLast();
    }
    Store.setJson(K.ords, ords);
    _at = 0;
    notifyListeners();
  }

  // ═══ ஆர்டர் செய்தல் ═══
  static Future<Map<String, dynamic>> placeOrder(Map<String, dynamic> params) async {
    final fnm = params['p_sched_at'] != null ? 'place_order_sched' : 'place_order';
    final r = await Api.rpc(fnm, params, timeout: const Duration(seconds: 20));
    if (r.status == 0) return {'ok': false, 'code': 'NET', 'msg': '📴 Network பிரச்சனை — இணையம் சரிபார்த்து மீண்டும் முயற்சிக்கவும்'};
    if (!r.ok) {
      if (r.status == 404) {
        return {
          'ok': false,
          'code': 'NO_RPC',
          'msg': fnm == 'place_order_sched' ? 'முன்பதிவு வசதி இன்னும் அமைக்கப்படவில்லை (schedule.sql)' : 'Server function இன்னும் அமைக்கப்படவில்லை (place_order.sql run செய்யுங்கள்)'
        };
      }
      return {'ok': false, 'code': 'HTTP', 'msg': 'ஆர்டர் சேமிக்க முடியவில்லை (HTTP ${r.status}) — மீண்டும் முயற்சிக்கவும்'};
    }
    if (r.data is Map) return Map<String, dynamic>.from(r.data as Map);
    return {'ok': false, 'code': 'EMPTY', 'msg': 'Server பதில் இல்லை — மீண்டும் முயற்சிக்கவும்'};
  }

  // ═══ வாடிக்கையாளர் ரத்து ═══
  static Future<Map<String, dynamic>> cancel(OrderV o) async {
    final r = await Api.rpc('customer_cancel_order', {'p_id': o.id, 'p_phone': o.ph});
    if (r.ok && r.data is Map) return Map<String, dynamic>.from(r.data as Map);
    return {'ok': false};
  }
}

// ═══ மீண்டும் வாங்க: அதே pack இல்லாவிட்டால் மாற்று pack (வாடிக்கையாளரிடம் கேட்டு) ═══
class ReoLine {
  final Product p;
  final int pi, qty;
  final String nm, was, now;
  final double price;
  ReoLine(this.p, this.pi, this.qty, {this.nm = '', this.was = '', this.now = '', this.price = 0});
}

class ReoPlan {
  final List<ReoLine> matched = [], alts = [];
  final List<String> gone = [];
  int priceUp = 0;
  String error = '';
}

ReoPlan reorderPlan(OrderV o) {
  final s = AppState.I;
  final plan = ReoPlan();
  final sid = o.shopId ?? kDefaultShopId;
  final sh = s.shopById(sid);
  if (sh == null || sh.hidden) {
    plan.error = '⚠️ இந்த கடை தற்போது கிடைக்கவில்லை';
    return plan;
  }
  bool pkOk(Pack pk) => !pk.isOut;
  for (final it in o.its) {
    final nm = it.n;
    Product? p = it.pid != null ? s.prods.where((x) => x.key == js(it.pid) && !x.hidden).first0 : null;
    p ??= s.prods.where((x) => !x.hidden && x.shopId == sid && x.name == it.n).first0;
    if (p == null || p.oos || p.packs.isEmpty) {
      plan.gone.add(nm);
      continue;
    }
    final qty = it.q > 0 ? it.q : 1;
    final pi = p.packs.indexWhere((pk) => pk.w == it.w);
    if (pi >= 0 && pkOk(p.packs[pi])) {
      if (it.up != null && p.packs[pi].price > it.up!) plan.priceUp++;
      plan.matched.add(ReoLine(p, pi, qty));
      continue;
    }
    final ai = p.packs.indexWhere(pkOk);
    if (ai < 0) {
      plan.gone.add(nm);
      continue;
    }
    plan.alts.add(ReoLine(p, ai, qty, nm: nm, was: it.w, now: p.packs[ai].w, price: p.packs[ai].price));
  }
  if (plan.matched.isEmpty && plan.alts.isEmpty) plan.error = '⚠️ இந்த ஆர்டரின் பொருட்கள் தற்போது கிடைக்கவில்லை';
  return plan;
}
