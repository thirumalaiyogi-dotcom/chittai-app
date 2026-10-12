// சிட்டை — தரவு வடிவங்கள். Server-லிருந்து வரும் JSON map-ஐ அப்படியே வைத்து, தேவையான field-களை மட்டும் படிக்கிறோம்
// (புதிய field-கள் admin சேர்த்தாலும் எதுவும் உடையாது; offline cache-லும் அப்படியே சேமிக்கப்படும்).
import 'config.dart';
import 'util.dart';

class Pack {
  final Map<String, dynamic> m;
  Pack(this.m);
  String get w => js(m['w']).trim().isEmpty ? '' : js(m['w']);
  double get price => jn(m['price']);
  dynamic get mrp => m['mrp'];
  Offer? get offer => pkOfferRaw(m['price'], m['mrp']);
  // stock.sql / inventory.sql-லிருந்து வந்த எண்ணிக்கை
  int? get qtyLeft => m['_qty'] is num ? (m['_qty'] as num).toInt() : null;
  bool get isOut => m['stock'] == 0 || m['stock'] == 'out' || m['available'] == false;
}

class Product {
  final Map<String, dynamic> m;
  late final List<Pack> packs;
  Product(this.m) {
    final raw = m['packs'];
    packs = raw is List ? raw.whereType<Map>().map((x) => Pack(Map<String, dynamic>.from(x))).toList() : <Pack>[];
    m['packs'] = packs.map((p) => p.m).toList();
  }
  dynamic get id => m['id'];
  String get key => js(m['id']);
  String get shopId => js(m['shop_id']).isEmpty ? kDefaultShopId : js(m['shop_id']);
  String get category => js(m['category_id'] ?? m['category']);
  String get name => js(m['name']);
  String get brand => js(m['brand']);
  String get emoji => js(m['emoji']).isEmpty ? '🛒' : js(m['emoji']);
  String get photo => js(m['photo']);
  dynamic get stock => m['stock'];
  bool get hidden => m['hidden'] == true;
  String get description => js(m['description']).trim();
  String get createdAt => js(m['created_at']);

  // seAvail: கையிருப்பு உள்ளதா
  bool get avail {
    final st = js(m['stock']).toLowerCase().trim();
    if (const ['out', 'out_of_stock', 'unavailable', 'no', 'none', '0', 'false', 'nil'].contains(st)) return false;
    if (m['in_stock'] == false || m['available'] == false || m['is_available'] == false) return false;
    if (packs.isNotEmpty && packs.every((k) => k.isOut)) return false;
    return true;
  }

  bool get oos => !avail;

  Offer? get bestOffer {
    Offer? best;
    for (final pk in packs) {
      final o = pk.offer;
      if (o != null && (best == null || o.off > best.off)) best = o;
    }
    return best;
  }

  double get minPrice {
    var v = double.infinity;
    for (final p in packs) {
      if (p.price < v) v = p.price;
    }
    return v.isFinite ? v : 0;
  }

  // seAttrs: attributes{} → எழுத்து map
  Map<String, String> get attrs {
    final a = m['attributes'];
    final o = <String, String>{};
    if (a is! Map) return o;
    a.forEach((k, v) {
      if (v == null || v == '') return;
      if (v is String || v is num || v is bool) {
        o[k.toString()] = v == true ? 'ஆம்' : (v == false ? 'இல்லை' : v.toString());
      }
    });
    return o;
  }
}

class Cat {
  final Map<String, dynamic> m;
  Cat(this.m);
  String get id => js(m['id']);
  String get shopId => js(m['shop_id']).isEmpty ? kDefaultShopId : js(m['shop_id']);
  String get e => js(m['e']);
  String get n => js(m['n']);
  String get photo => js(m['photo']);
  bool get hidden => m['hidden'] == true;
}

class Shop {
  final Map<String, dynamic> m;
  Shop(this.m);
  String get id => js(m['id']);
  String get name => js(m['name']);
  String get description => js(m['description']);
  String get logo => js(m['logo']);
  String get logoImage => js(m['logo_image']);
  String get coverImage => js(m['cover_image']);
  String get phone => js(m['phone']);
  String get address => js(m['address']);
  String get openingTime => js(m['opening_time']);
  String get closingTime => js(m['closing_time']);
  String get offerText => js(m['offer_text']).trim();
  String get shopType => js(m['shop_type']);
  String get mapUrl => js(m['map_url']);
  String get website => js(m['website']);
  String get distanceLabel => js(m['distance_label']);
  bool get hidden => m['hidden'] == true;
  bool get isOpenFlag => m['is_open'] != false;
  bool get deliveryAvailable => m['delivery_available'] != false;
  bool get acceptingOrders => m['accepting_orders'] != false;
  dynamic get deliveryMin => m['delivery_min'];
  dynamic get deliveryMax => m['delivery_max'];
  double get sortOrder => jz(m['sort_order']);
  double? get lat => m['lat'] == null || jn(m['lat']).isNaN ? null : jn(m['lat']);
  double? get lng => m['lng'] == null || jn(m['lng']).isNaN ? null : jn(m['lng']);
  String get createdAt => js(m['created_at']);

  // "இடைவேளை இல்லாத" logo emoji (http link என்றால் emoji இல்லை)
  String logoEmoji(String fallback) {
    final l = logo;
    if (l.isNotEmpty && !RegExp(r'^https?:').hasMatch(l)) return l;
    return fallback;
  }

  bool get etaKnown => jt(m['delivery_min']) && jt(m['delivery_max']);
  String get etaText => etaKnown ? '${js(m['delivery_min'])}–${js(m['delivery_max'])}' : '';

  // shopIsOpen: is_open + நேரம் (இரவு தாண்டி மூடும் கடையும் சரி)
  bool get isOpenNow {
    if (m['is_open'] == false) return false;
    final o = openingTime, c = closingTime;
    if (o.isNotEmpty && c.isNotEmpty) {
      final a = hmToMin(o), b = hmToMin(c);
      final n = DateTime.now();
      final mm = n.hour * 60 + n.minute;
      if (a != null && b != null && a != b) return a < b ? (mm >= a && mm < b) : (mm >= a || mm < b);
    }
    return true;
  }

  // டெலிவரி கட்டண விவரம் (3 படி)
  List<String> get feeText {
    final x = <String>[];
    final ch = jz(m['delivery_charge']), ra = jz(m['reduced_above']), c2 = jz(m['delivery_charge2']), fa = jz(m['free_delivery_above']);
    if (ch > 0) x.add('கட்டணம் ₹${rupee(ch)}');
    if (ch > 0 && ra > 0 && (fa == 0 || ra < fa)) x.add('₹${rupee(ra)}-க்கு மேல் ${c2 > 0 ? '₹${rupee(c2)}' : 'இலவசம்'}');
    if (ch > 0 && fa > 0) x.add('₹${rupee(fa)}-க்கு மேல் இலவசம்');
    return x;
  }
}

class Kind {
  final String id, n, e, c, cc;
  final double s;
  final bool hide;
  const Kind({required this.id, required this.n, required this.e, required this.c, this.cc = '', this.s = 0, this.hide = false});
}

class CartLine {
  final Product product;
  final int packIdx;
  int qty;
  CartLine(this.product, this.packIdx, this.qty);
  Pack get pack => product.packs[packIdx];
  String get key => '${product.key}_$packIdx';
}

class Totals {
  final double del, tot;
  const Totals(this.del, this.tot);
}

// calcOrderTotals: place_order-ன் அதே 3-படி விதி (server தான் இறுதி)
Totals calcOrderTotals(Shop? shop, double sub) {
  var del = 0.0;
  if (shop != null && shop.deliveryAvailable) {
    final ch = jz(shop.m['delivery_charge']), fa = jz(shop.m['free_delivery_above']), ra = jz(shop.m['reduced_above']);
    if (ch > 0 && !(fa > 0 && sub >= fa)) {
      del = ch;
      if (ra > 0 && sub >= ra) del = jz(shop.m['delivery_charge2']);
    }
  }
  return Totals(del, round2(sub + del));
}
