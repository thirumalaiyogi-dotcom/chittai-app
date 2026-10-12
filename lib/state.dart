// சிட்டை — app முழுவதன் தரவு: கடைகள், பொருட்கள், கூடை, விருப்பங்கள், இடம், அமைப்புகள்
import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'config.dart';
import 'models.dart';
import 'store.dart';
import 'util.dart';

// கடை வகைகள் (index.html SHOP_TYPES — admin shop_types table மூலம் மாற்றலாம்)
const List<Kind> kKindBase = [
  Kind(id: 'grocery', n: 'மளிகை', e: '🛒', c: '#e8f5ef'),
  Kind(id: 'vegetables', n: 'காய்கறி', e: '🥬', c: '#eaf7e4'),
  Kind(id: 'fruits', n: 'பழங்கள்', e: '🍎', c: '#fdecec'),
  Kind(id: 'medical', n: 'மருந்தகம்', e: '💊', c: '#e8f0fd'),
  Kind(id: 'dairy', n: 'பால் பொருட்கள்', e: '🥛', c: '#f1f5f9'),
  Kind(id: 'meat', n: 'இறைச்சி / மீன்', e: '🍗', c: '#fdeee6'),
  Kind(id: 'bakery', n: 'பேக்கரி', e: '🍰', c: '#fdf2e3'),
  Kind(id: 'food', n: 'உணவகம்', e: '🍛', c: '#fff4dd'),
  Kind(id: 'flowers', n: 'பூக்கள் / பூஜை', e: '🌸', c: '#fcebf3'),
  Kind(id: 'others', n: 'மற்றவை', e: '🛍️', c: '#efeefc'),
];
const List<String> kKindPal = ['#e3f3e6', '#fde7ea', '#e4edfb', '#fdf0dd', '#f1e7fb', '#fce7f1', '#e6f4dc', '#fde9df', '#ecebfb', '#e3eefc'];
const Map<String, String> kKindPalId = {
  'grocery': '#e3f3e6',
  'vegetables': '#e6f4dc',
  'fruits': '#fde7ea',
  'medical': '#e4edfb',
  'dairy': '#e3eefc',
  'meat': '#fde9df',
  'bakery': '#fdf0dd',
  'food': '#f1e7fb',
  'flowers': '#fce7f1',
  'others': '#ecebfb',
};

class AppState extends ChangeNotifier {
  AppState._();
  static final AppState I = AppState._();

  // ── தரவு ──
  List<Product> prods = [];
  List<Cat> cats = [];
  List<Shop> shops = [];
  List<Kind> kinds = List.of(kKindBase);
  Map<String, String> kindImg = {};
  List<Map<String, dynamic>> banners = [];
  List<Map<String, dynamic>> stories = [];
  List<Map<String, dynamic>> popups = [];
  Map<String, dynamic>? rev; // review_summary (null = reviews.sql இல்லை)
  String notice = '';
  String waNum = kDefaultWaNum;

  bool cloudLoading = true;
  bool cloudFail = false;
  bool shopsCached = false;
  bool prodsCached = false;
  int ver = 0; // தரவு மாறும்போது கூடும் (தேடல் index மீண்டும் கட்ட)

  // ── கூடை (ஒரு கடை மட்டும்) ──
  final LinkedHashMap<String, CartLine> cart = LinkedHashMap();
  List<dynamic> favIds = [];

  // ── இடம் ──
  double? userLat, userLng;
  String locState = 'idle';

  String activeShop = kDefaultShopId;
  bool dark = false;
  String fs = '2';

  // ═══ தொடக்கம்: phone-ல் சேமித்ததை உடனே காட்டு ═══
  void loadLocal() {
    dark = Store.str(K.theme) == 'wa_dark';
    fs = Store.str(K.fs) ?? '2';
    waNum = Store.str(K.wa) ?? kDefaultWaNum;
    notice = Store.str(K.notice) ?? '';
    activeShop = Store.str(K.activeShop) ?? kDefaultShopId;

    final p = Store.json(K.prods), c = Store.json(K.cats), s = Store.json(K.shops);
    prodsCached = p is List && p.isNotEmpty;
    shopsCached = s is List && s.isNotEmpty;
    if (p is List) prods = _mapList(p).map(Product.new).toList();
    if (c is List) cats = _mapList(c).map(Cat.new).toList();
    if (s is List) shops = _mapList(s).map(Shop.new).toList();
    final k = Store.json(K.kinds);
    if (k is List) kindsApply(k);
    final b = Store.json(K.banners);
    if (b is List) banners = _mapList(b);
    final st = Store.json(K.stories);
    if (st is List) stories = _mapList(st);
    final r = Store.json(K.rev);
    if (r is Map) rev = Map<String, dynamic>.from(r);

    final f = Store.json(K.favs);
    if (f is List) favIds = List.of(f);

    final l = Store.json(K.userLoc);
    if (l is Map && l['lat'] != null) {
      final t = jz(l['t']);
      if (DateTime.now().millisecondsSinceEpoch - t < 6 * 3600 * 1000) {
        userLat = jn(l['lat']);
        userLng = jn(l['lng']);
        locState = 'ok';
      }
    }
    _restoreCart();
    ver++;
  }

  static List<Map<String, dynamic>> _mapList(List l) =>
      l.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();

  // ═══ Cloud-லிருந்து புதிய தரவு ═══
  bool _loadingNow = false;
  Future<void> runCloudLoad() async {
    if (_loadingNow) return;
    _loadingNow = true;
    cloudLoading = true;
    cloudFail = false;
    notifyListeners();
    try {
      final side = Future.wait([loadKinds(), loadBanners(), loadStories(), loadPopups(), loadReviews(), loadAppSettings()]);
      final res = await Future.wait([Api.table('products'), Api.table('categories'), Api.table('shops')]);
      final pr = res[0], cr = res[1], sr = res[2];
      if (!pr.ok || pr.data is! List) {
        cloudFail = true;
      } else if ((pr.data as List).isNotEmpty) {
        prods = _mapList(pr.data as List).map(Product.new).toList();
        Store.setStr(K.prods, pr.body);
        prodsCached = true;
      }
      if (!cr.ok || cr.data is! List) {
        cloudFail = true;
      } else if ((cr.data as List).isNotEmpty) {
        cats = _mapList(cr.data as List).map(Cat.new).toList();
        Store.setStr(K.cats, cr.body);
      }
      if (!sr.ok || sr.data is! List) {
        cloudFail = true;
      } else if ((sr.data as List).isNotEmpty) {
        shops = _mapList(sr.data as List).map(Shop.new).toList();
        Store.setStr(K.shops, sr.body);
        shopsCached = true;
      }
      await applyPackStock();
      if (!cloudFail && cart.isNotEmpty) refreshCartPrices();
      ver++;
      await side.timeout(const Duration(seconds: 25), onTimeout: () => const []);
    } catch (_) {
      cloudFail = true;
    } finally {
      cloudLoading = false;
      _loadingNow = false;
      ver++;
      notifyListeners();
    }
  }

  // 📦 pack எண்ணிக்கை (stock.sql) + 🧾 அலகுக் கையிருப்பு (inventory.sql)
  Future<void> applyPackStock() async {
    try {
      final r = await Api.getPath('pack_stock?select=product_id,pack,qty,low_at');
      if (!r.ok || r.data is! List) return;
      final m = <String, Map<String, dynamic>>{};
      for (final x in _mapList(r.data as List)) {
        m['${js(x['product_id'])}|${js(x['pack'])}'] = x;
      }
      try {
        final ri = await Api.getPath('inv?select=product_id,unit,qty,packq');
        if (ri.ok && ri.data is List) {
          for (final x in _mapList(ri.data as List)) {
            final p = prods.where((q) => q.key == js(x['product_id'])).first0;
            if (p == null) continue;
            for (final pk in p.packs) {
              final k = '${p.key}|${pk.w}';
              if (pk.w.isNotEmpty && !m.containsKey(k)) {
                final f = invPackFactor(pk.w, js(x['unit']), x['packq']);
                m[k] = {'qty': ((jz(x['qty']) + 1e-9) / f).floor(), 'low_at': 0, '_inv': 1};
              }
            }
          }
        }
      } catch (_) {}
      var ch = false;
      for (final p in prods) {
        for (final pk in p.packs) {
          final t = m['${p.key}|${pk.w}'];
          if (t != null) {
            final q = jz(t['qty']);
            pk.m['_qty'] = q.toInt();
            pk.m['_low'] = t['low_at'];
            if (q <= 0 && pk.m['stock'] != 'out') {
              pk.m['stock'] = 'out';
              pk.m['_auto'] = 1;
              ch = true;
            } else if (q > 0 && pk.m['_auto'] != null) {
              pk.m.remove('stock');
              pk.m.remove('_auto');
              ch = true;
            }
          } else if (pk.m['_auto'] != null) {
            pk.m.remove('stock');
            pk.m.remove('_auto');
            pk.m.remove('_qty');
            ch = true;
          }
        }
      }
      if (ch) {
        ver++;
        notifyListeners();
      }
    } catch (_) {}
  }

  // ⚙️ support எண் + 📢 அறிவிப்புப் பட்டை
  Future<void> loadAppSettings() async {
    var r = await Api.getPath('app_settings?select=support_phone,notice,notice_until&id=eq.1');
    if (!r.ok) r = await Api.getPath('app_settings?select=support_phone&id=eq.1');
    if (!r.ok || r.data is! List) return;
    final l = r.data as List;
    final x = l.isNotEmpty && l[0] is Map ? Map<String, dynamic>.from(l[0] as Map) : <String, dynamic>{};
    var ch = false;
    final v = js(x['support_phone']);
    if (v.isNotEmpty && RegExp(r'^91[6-9]\d{9}$').hasMatch(v) && v != waNum) {
      waNum = v;
      Store.setStr(K.wa, v);
      ch = true;
    }
    var n = '';
    if (jsTruthy(x['notice'])) {
      final until = DateTime.tryParse(js(x['notice_until']));
      if (x['notice_until'] == null || until == null || until.isAfter(DateTime.now())) n = js(x['notice']);
    }
    if (n != notice) {
      notice = n;
      Store.setStr(K.notice, n);
      ch = true;
    }
    if (ch) notifyListeners();
  }

  // notice_until நேரம் முடிந்ததா (app திறந்திருக்கும்போதே)
  Future<void> loadKinds() async {
    final r = await Api.table('shop_types');
    if (!r.ok || r.data is! List) return;
    kindsApply(r.data as List);
    Store.setStr(K.kinds, r.body);
    ver++;
    notifyListeners();
  }

  void kindsApply(List rows) {
    final by = <String, Map<String, dynamic>>{};
    for (final r in _mapList(rows)) {
      if (js(r['id']).isNotEmpty) by[js(r['id'])] = r;
    }
    final out = <Kind>[];
    for (var i = 0; i < kKindBase.length; i++) {
      final t = kKindBase[i];
      final r = by[t.id] ?? const {};
      out.add(Kind(
        id: t.id,
        n: js(r['name']).isNotEmpty ? js(r['name']) : t.n,
        e: js(r['emoji']).isNotEmpty ? js(r['emoji']) : t.e,
        c: t.c,
        cc: js(r['color']),
        s: r['sort_order'] != null ? jz(r['sort_order']) : i * 10.0,
        hide: r['hidden'] == true,
      ));
    }
    var j = 0;
    for (final id in by.keys) {
      final jj = j++;
      if (kKindBase.any((t) => t.id == id)) continue;
      final r = by[id]!;
      if (js(r['name']).isEmpty) continue;
      out.add(Kind(
        id: id,
        n: js(r['name']),
        e: js(r['emoji']).isNotEmpty ? js(r['emoji']) : '🛍️',
        c: kKindPal[jj % kKindPal.length],
        cc: js(r['color']),
        s: r['sort_order'] != null ? jz(r['sort_order']) : 1000.0 + jj,
        hide: r['hidden'] == true,
      ));
    }
    out.sort((a, b) => a.s.compareTo(b.s));
    kinds = out;
    final m = <String, String>{};
    by.forEach((id, r) {
      final u = js(r['image']);
      if (u.startsWith('https://')) m[id] = u;
    });
    kindImg = m;
  }

  Future<void> loadBanners() async {
    final r = await Api.table('banners');
    if (!r.ok || r.data is! List) return;
    banners = _mapList(r.data as List);
    Store.setStr(K.banners, r.body);
    notifyListeners();
  }

  Future<void> loadStories() async {
    final r = await Api.table('stories');
    if (!r.ok || r.data is! List) return;
    stories = _mapList(r.data as List);
    Store.setStr(K.stories, r.body);
    notifyListeners();
  }

  Future<void> loadPopups() async {
    final r = await Api.table('popups');
    if (!r.ok || r.data is! List) return;
    popups = _mapList(r.data as List);
  }

  Future<void> loadReviews() async {
    final r = await Api.rpc('review_summary', const {});
    if (!r.ok || r.data is! Map) return;
    rev = Map<String, dynamic>.from(r.data as Map);
    Store.setStr(K.rev, r.body);
    notifyListeners();
  }

  // ═══ கடை உதவிகள் ═══
  Shop? shopById(String id) => shops.where((s) => s.id == id).first0;
  List<Shop> get visibleShops => shops.where((s) => !s.hidden).toList();

  String shopType(Shop? s) {
    if (s != null && s.shopType.isNotEmpty && kinds.any((t) => t.id == s.shopType)) return s.shopType;
    return 'grocery';
  }

  Kind? kindOf(Shop? s) {
    final id = shopType(s);
    return kinds.where((t) => t.id == id).first0;
  }

  Kind? kindById(String id) => kinds.where((t) => t.id == id).first0;

  String kindBg(Kind t) => t.cc.isNotEmpty ? t.cc : (kKindPalId[t.id] ?? t.c);

  double? shopKm(Shop s) {
    if (userLat == null || userLng == null || s.lat == null || s.lng == null) return null;
    return kmBetween(userLat!, userLng!, s.lat!, s.lng!);
  }

  String shopDistText(Shop s) {
    final k = shopKm(s);
    if (k != null) return k < 1 ? '${(k * 1000).round()} m' : '${k.toStringAsFixed(1)} km';
    return s.distanceLabel;
  }

  Map<String, dynamic>? revOf(Shop s) {
    final r = rev?[s.id];
    return r is Map ? Map<String, dynamic>.from(r) : null;
  }

  double? shopRating(Shop s) {
    if (rev != null) {
      final r = revOf(s);
      return r != null && jz(r['n']) > 0 ? jz(r['avg']) : null;
    }
    final v = jn(s.m['rating']);
    return (!v.isNaN && v > 0 && v <= 5) ? v : null;
  }

  int shopReviewCount(Shop s) {
    if (rev != null) {
      final r = revOf(s);
      return r != null ? jz(r['n']).toInt() : 0;
    }
    final n = jz(s.m['review_count']).floor();
    return n > 0 ? n : 0;
  }

  // ஒரு கடையில் காட்டக்கூடிய வகைகள் (பொருள் உள்ளவை மட்டும்)
  List<Cat> shopCats(String shopId) => cats
      .where((c) => c.shopId == shopId && !c.hidden && prods.any((p) => p.category == c.id && !p.hidden && p.shopId == shopId))
      .toList();

  List<Product> catProds(String shopId, String catId) =>
      prods.where((p) => p.category == catId && !p.hidden && p.shopId == shopId).toList();

  Product? prodByKey(String k) => prods.where((p) => p.key == k).first0;

  // ═══ சுயவிவரம் (kd_profile) ═══
  Map<String, dynamic> profRaw() {
    final p = Store.json(K.profile);
    return p is Map ? Map<String, dynamic>.from(p) : <String, dynamic>{};
  }

  // பெயர் + சரியான எண் + முகவரி மூன்றும் இருந்தால் மட்டும்
  Map<String, dynamic>? profGet() {
    final p = profRaw();
    if (js(p['nm']).isNotEmpty && RegExp(r'^[6-9]\d{9}$').hasMatch(js(p['ph'])) && js(p['ad']).isNotEmpty) return p;
    return null;
  }

  List<Map<String, dynamic>> ordLocal() {
    final a = Store.json(K.ords);
    return a is List ? _mapList(a) : <Map<String, dynamic>>[];
  }

  // ═══ கூடை ═══
  String ck(Product p, int pi) => '${p.key}_$pi';
  int qtyOf(Product p, int pi) => cart[ck(p, pi)]?.qty ?? 0;
  int totalQtyOf(Product p) {
    var n = 0;
    for (var i = 0; i < p.packs.length; i++) {
      n += qtyOf(p, i);
    }
    return n;
  }

  int get cartCount => cart.values.fold(0, (s, c) => s + c.qty);
  double get cartAmount => round2(cart.values.fold(0.0, (s, c) => s + c.pack.price * c.qty));
  String? get cartShopId => cart.isEmpty ? null : cart.values.first.product.shopId;
  bool conflicts(Product p) => cartShopId != null && cartShopId != p.shopId;

  void addLine(Product p, int pi, {int qty = 1}) {
    if (pi < 0 || pi >= p.packs.length) return;
    cart[ck(p, pi)] = CartLine(p, pi, qty);
    _saveCart();
    notifyListeners();
  }

  void change(Product p, int pi, int d) {
    final k = ck(p, pi);
    final c = cart[k];
    if (c == null) return;
    c.qty += d;
    if (c.qty <= 0) cart.remove(k);
    _saveCart();
    notifyListeners();
  }

  void removeAll(Product p) {
    cart.removeWhere((k, v) => v.product.key == p.key);
    _saveCart();
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    _saveCart();
    notifyListeners();
  }

  void _saveCart() {
    final m = <String, dynamic>{};
    cart.forEach((k, c) => m[k] = {'pid': c.product.id, 'w': c.pack.w, 'packIdx': c.packIdx, 'qty': c.qty});
    Store.setJson(K.cart, m);
  }

  void _restoreCart() {
    cart.clear();
    final d = Store.json(K.cart);
    if (d is! Map) return;
    d.forEach((k, v) {
      if (v is! Map) return;
      // web app வடிவம் {product:{...},pack:{...}} அல்லது நம் வடிவம் {pid,w}
      final pid = js(v['pid'] ?? (v['product'] is Map ? (v['product'] as Map)['id'] : null));
      final w = js(v['w'] ?? (v['pack'] is Map ? (v['pack'] as Map)['w'] : null));
      final q = jz(v['qty']).toInt();
      final p = prodByKey(pid);
      if (p == null || q <= 0) return;
      final pi = p.packs.indexWhere((pk) => pk.w == w);
      if (pi < 0) return;
      cart[ck(p, pi)] = CartLine(p, pi, q);
    });
  }

  // புதிய விலை / கையிருப்பு வந்ததும் கூடையை server தரவுக்கு மாற்று
  void refreshCartPrices() {
    final old = cart.values.toList();
    cart.clear();
    for (final it in old) {
      final p = prods.where((x) => x.key == it.product.key && !x.hidden).first0;
      final pi = p == null ? -1 : p.packs.indexWhere((pk) => pk.w == it.pack.w);
      if (p == null || pi < 0 || p.oos) continue;
      cart[ck(p, pi)] = CartLine(p, pi, it.qty);
    }
    _saveCart();
  }

  // ═══ விருப்பங்கள் ═══
  bool favHas(Product p) => favIds.any((x) => js(x) == p.key);
  bool favToggle(Product p) {
    final i = favIds.indexWhere((x) => js(x) == p.key);
    final adding = i < 0;
    if (adding) {
      favIds.add(p.id);
    } else {
      favIds.removeAt(i);
    }
    Store.setJson(K.favs, favIds);
    notifyListeners();
    return adding;
  }

  // ═══ இடம் ═══
  void setUserLoc(double lat, double lng) {
    userLat = lat;
    userLng = lng;
    locState = 'ok';
    Store.setJson(K.userLoc, {'lat': lat, 'lng': lng, 't': DateTime.now().millisecondsSinceEpoch});
    notifyListeners();
  }

  void clearUserLoc() {
    userLat = null;
    userLng = null;
    locState = 'idle';
    Store.remove(K.userLoc);
    notifyListeners();
  }

  // ═══ அமைப்புகள் ═══
  void setDark(bool v) {
    dark = v;
    Store.setStr(K.theme, v ? 'wa_dark' : 'wa_light');
    notifyListeners();
  }

  void setFs(String v) {
    fs = v;
    Store.setStr(K.fs, v);
    notifyListeners();
  }

  double get textScale => const {'1': 0.92, '2': 1.0, '3': 1.14}[fs] ?? 1.0;

  void setActiveShop(String id) {
    activeShop = id;
    Store.setStr(K.activeShop, id);
    Store.setStr(K.shopChosen, '1');
  }

  Map<String, dynamic> revDoneMap() {
    final m = Store.json(K.revDone);
    return m is Map ? Map<String, dynamic>.from(m) : <String, dynamic>{};
  }

  void ping() => notifyListeners();

  static String enc(Object o) => jsonEncode(o);
}
