// சிட்டை — SMART SEARCH ENGINE (index.html-ல் உள்ள அதே விதிகள், Dart-ல்)
// தமிழ் / ஆங்கிலம் / Tanglish (paal → பால்), எழுத்துப் பிழை பொறுத்தல், மதிப்பெண், வடிகட்டல், வரிசை.
import 'config.dart';
import 'models.dart';
import 'state.dart';
import 'store.dart';
import 'util.dart';

// ஆங்கிலம் → தமிழ் (தேடலை விரிவாக்க மட்டும் — முடிவுகள் எப்போதும் உண்மைத் தரவிலிருந்தே)
const Map<String, String> kSearchAliases = {
  'milk': 'பால்', 'curd': 'தயிர்', 'butter': 'வெண்ணெய்', 'ghee': 'நெய்', 'rice': 'அரிசி', 'dal': 'பருப்பு', 'dhal': 'பருப்பு',
  'pulses': 'பருப்பு', 'oil': 'எண்ணெய்', 'salt': 'உப்பு', 'sugar': 'சர்க்கரை', 'jaggery': 'வெல்லம்', 'flour': 'மாவு', 'atta': 'மாவு',
  'wheat': 'கோதுமை', 'rava': 'ரவை', 'tea': 'டீ', 'coffee': 'காபி', 'tomato': 'தக்காளி', 'onion': 'வெங்காயம்',
  'potato': 'உருளைக்கிழங்கு', 'brinjal': 'கத்தரிக்காய்', 'chilli': 'மிளகாய்', 'chili': 'மிளகாய்', 'coconut': 'தேங்காய்',
  'banana': 'வாழைப்பழம்', 'mango': 'மாம்பழம்', 'apple': 'ஆப்பிள்', 'lemon': 'எலுமிச்சை', 'garlic': 'பூண்டு', 'ginger': 'இஞ்சி',
  'egg': 'முட்டை', 'chicken': 'கோழி', 'fish': 'மீன்', 'mutton': 'ஆட்டிறைச்சி', 'bread': 'ரொட்டி', 'biscuit': 'பிஸ்கட்',
  'soap': 'சோப்பு', 'turmeric': 'மஞ்சள்', 'pepper': 'மிளகு', 'masala': 'மசாலா', 'flower': 'பூ', 'jasmine': 'மல்லிகை',
  'medicine': 'மருந்து', 'vegetable': 'காய்கறி', 'vegetables': 'காய்கறி', 'fruit': 'பழம்', 'fruits': 'பழங்கள்',
  'grocery': 'மளிகை', 'snacks': 'சிப்ஸ்', 'drinks': 'பானம்', 'sweets': 'இனிப்பு',
};

const Map<String, String> _taV = {
  'அ': 'a', 'ஆ': 'aa', 'இ': 'i', 'ஈ': 'ii', 'உ': 'u', 'ஊ': 'uu', 'எ': 'e', 'ஏ': 'ee', 'ஐ': 'ai', 'ஒ': 'o', 'ஓ': 'oo', 'ஔ': 'au', 'ஃ': 'h'
};
const Map<String, String> _taC = {
  'க': 'k', 'ங': 'ng', 'ச': 's', 'ஞ': 'nj', 'ட': 'd', 'ண': 'n', 'த': 'th', 'ந': 'n', 'ப': 'p', 'ம': 'm', 'ய': 'y', 'ர': 'r',
  'ல': 'l', 'வ': 'v', 'ழ': 'zh', 'ள': 'l', 'ற': 'r', 'ன': 'n', 'ஜ': 'j', 'ஷ': 'sh', 'ஸ': 's', 'ஹ': 'h'
};
const Map<String, String> _taS = {
  'ா': 'aa', 'ி': 'i', 'ீ': 'ii', 'ு': 'u', 'ூ': 'uu', 'ெ': 'e', 'ே': 'ee', 'ை': 'ai', 'ொ': 'o', 'ோ': 'oo', 'ௌ': 'au'
};
const String _virama = '்';

// தமிழ் → ஆங்கில ஒலி (Tanglish ஒப்பிட)
String taLatin(String s) {
  final a = s.runes.map(String.fromCharCode).toList();
  final o = StringBuffer();
  for (var i = 0; i < a.length; i++) {
    final ch = a[i];
    final c = _taC[ch];
    if (c != null) {
      final nx = i + 1 < a.length ? a[i + 1] : '';
      if (nx == _virama) {
        o.write(c);
        i++;
      } else if (_taS.containsKey(nx)) {
        o.write(c + _taS[nx]!);
        i++;
      } else {
        o.write('${c}a');
      }
    } else if (_taV.containsKey(ch)) {
      o.write(_taV[ch]);
    } else if (_taS.containsKey(ch) || ch == _virama) {
      continue;
    } else {
      o.write(ch);
    }
  }
  return o.toString();
}

// ஒலிச் சட்டகம்: th/t, zh/l, aa/a, kk/k, ch/s/j, g/k, b/p, d/t... வித்தியாசங்களை மடக்கும்
String skel(String s0) {
  var s = s0.toLowerCase();
  s = s.replaceAll('zh', 'l');
  s = s.replaceAll(RegExp(r'sh|ch'), 's');
  s = s.replaceAll(RegExp(r'th|dh'), 't');
  s = s.replaceAll(RegExp(r'ph|f'), 'p');
  s = s.replaceAll(RegExp(r'bh|b'), 'p');
  s = s.replaceAll(RegExp(r'kh|gh|g|q|c(?!h)'), 'k');
  s = s.replaceAll(RegExp(r'nj|ng'), 'n');
  s = s.replaceAll(RegExp(r'j|z'), 's');
  s = s.replaceAll('d', 't');
  s = s.replaceAll('w', 'v');
  s = s.replaceAll('x', 'ks');
  s = s.replaceAll(RegExp(r'ee|ii|y(?=[aeiou])'), 'i');
  s = s.replaceAll(RegExp(r'oo|uu'), 'u');
  s = s.replaceAll(RegExp(r'ai|ay'), 'e');
  s = s.replaceAll('au', 'o');
  s = s.replaceAllMapped(RegExp(r'([a-z])\1+'), (m) => m.group(1)!);
  s = s.replaceAll(RegExp(r'[^a-z0-9 ]'), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

final RegExp _zw = RegExp('[​-‍﻿]');
final RegExp _nonWord = RegExp(r'[^\p{L}\p{M}\p{N}\s.]', unicode: true);
final RegExp _tamil = RegExp('[஀-௿]');

String normalizeSearchText(dynamic t) {
  var s = (t == null ? '' : t.toString()).replaceAll(_zw, '').toLowerCase();
  s = s.replaceAll(_nonWord, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.length > 80 ? s.substring(0, 80) : s;
}

class SeTok {
  final String t, sk, al;
  final bool lat;
  const SeTok(this.t, this.lat, this.sk, this.al);
}

List<SeTok> getSearchTokens(String q) {
  final n = normalizeSearchText(q);
  if (n.isEmpty) return const [];
  final seen = <String>{};
  final out = <SeTok>[];
  for (final t in n.split(' ')) {
    if (t.isEmpty || !seen.add(t)) continue;
    if (out.length >= 6) break;
    final lat = RegExp(r'[a-z]').hasMatch(t) && !_tamil.hasMatch(t);
    out.add(SeTok(t, lat, lat && t.length >= 3 ? skel(t) : '', lat && kSearchAliases.containsKey(t) ? normalizeSearchText(kSearchAliases[t]) : ''));
  }
  return out;
}

class SeItem {
  final Product p;
  final Shop sh;
  final Cat? cat;
  final String n, b, c, s, x, sk, skN;
  final double minP;
  final bool off, avail;
  final List<String> packs;
  final Map<String, String> attrs;
  SeItem({
    required this.p,
    required this.sh,
    required this.cat,
    required this.n,
    required this.b,
    required this.c,
    required this.s,
    required this.x,
    required this.sk,
    required this.skN,
    required this.minP,
    required this.off,
    required this.avail,
    required this.packs,
    required this.attrs,
  });
}

class SeShop {
  final Shop sh;
  final String n, d, sk;
  SeShop(this.sh, this.n, this.d, this.sk);
}

class SeCat {
  final String type; // cat / kind
  final Cat? c;
  final Kind? t;
  final String n, id, sk;
  SeCat(this.type, this.c, this.t, this.n, this.id, this.sk);
  String get label => type == 'cat' ? c!.n : t!.n;
}

class SeBrand {
  final String n, label, sk;
  SeBrand(this.n, this.label, this.sk);
}

class SeHit {
  final SeItem it;
  final double sc;
  SeHit(this.it, this.sc);
}

class SeIndex {
  final List<SeItem> items;
  final List<SeShop> shops;
  final List<SeCat> cats;
  final List<SeBrand> brands;
  SeIndex(this.items, this.shops, this.cats, this.brands);
}

// ── வடிகட்டல் நிலை ──
class SrF {
  List<String> shop = [], cat = [], brand = [], pack = [];
  String price = '';
  bool offer = false, open = false, near = false, avail = false, fast = false, rate = false;
  Map<String, List<String>> attr = {};

  SrF copy() {
    final f = SrF();
    f.shop = List.of(shop);
    f.cat = List.of(cat);
    f.brand = List.of(brand);
    f.pack = List.of(pack);
    f.price = price;
    f.offer = offer;
    f.open = open;
    f.near = near;
    f.avail = avail;
    f.fast = fast;
    f.rate = rate;
    f.attr = attr.map((k, v) => MapEntry(k, List.of(v)));
    return f;
  }

  bool quick(String k) => const {'offer', 'open', 'near', 'avail', 'fast', 'rate'}.contains(k) && _q(k);
  bool _q(String k) {
    switch (k) {
      case 'offer':
        return offer;
      case 'open':
        return open;
      case 'near':
        return near;
      case 'avail':
        return avail;
      case 'fast':
        return fast;
      case 'rate':
        return rate;
    }
    return false;
  }

  void toggleQuick(String k) {
    switch (k) {
      case 'offer':
        offer = !offer;
        break;
      case 'open':
        open = !open;
        break;
      case 'near':
        near = !near;
        break;
      case 'avail':
        avail = !avail;
        break;
      case 'fast':
        fast = !fast;
        break;
      case 'rate':
        rate = !rate;
        break;
    }
  }

  List<String> listOf(String k) => k == 'shop'
      ? shop
      : k == 'cat'
          ? cat
          : k == 'brand'
              ? brand
              : pack;

  int get count =>
      shop.length +
      cat.length +
      brand.length +
      pack.length +
      (price != '' ? 1 : 0) +
      [offer, open, near, avail, fast, rate].where((x) => x).length +
      attr.values.fold(0, (s, a) => s + a.length);
}

class FOpt {
  final String v, l;
  final int n;
  FOpt(this.v, this.l, this.n);
}

class AttrF {
  final String k;
  final List<FOpt> opts;
  AttrF(this.k, this.opts);
}

class AvailF {
  List<FOpt>? shop, cat, brand, pack, price;
  List<List<String>>? quick; // [key, label]
  List<AttrF>? attr;
}

const List<List<double>> kPriceBuckets = [
  [0, 50],
  [50, 100],
  [100, 250],
  [250, 500],
  [500, 1e9],
];
String seBucketLabel(List<double> b) => b[1] >= 1e9 ? '₹${b[0].toInt()}-க்கு மேல்' : '₹${b[0].toInt()} – ₹${b[1].toInt()}';

class SearchEngine {
  static SeIndex? _ix;
  static int _ver = -1;
  static AppState get S => AppState.I;

  static SeIndex index() {
    if (_ix != null && _ver == S.ver) return _ix!;
    final shopBy = <String, Shop>{};
    for (final s in S.shops) {
      if (!s.hidden) shopBy[s.id] = s;
    }
    final catBy = <String, Cat>{};
    for (final c in S.cats) {
      if (!c.hidden) catBy['${c.shopId}|${c.id}'] = c;
    }
    final items = <SeItem>[];
    final brands = <String, String>{};
    for (final p in S.prods) {
      if (p.hidden || p.packs.isEmpty) continue;
      final sh = shopBy[p.shopId];
      if (sh == null) continue;
      final packs = p.packs.where((k) => !k.price.isNaN && k.price.isFinite && k.price > 0).toList();
      if (packs.isEmpty) continue;
      final cat = catBy['${p.shopId}|${p.category}'];
      final extra = <String>[];
      void addX(dynamic v) {
        if (v == null) return;
        if (v is List) {
          extra.addAll(v.map((e) => e.toString()));
        } else {
          extra.add(v.toString());
        }
      }

      addX(p.m['tags']);
      addX(p.m['search_keywords']);
      addX(p.m['name_en']);
      if (p.m['attributes'] is Map) (p.m['attributes'] as Map).values.forEach(addX);
      final n = normalizeSearchText(p.name), b = normalizeSearchText(p.brand), c = normalizeSearchText('${cat?.n ?? ''} ${p.category}');
      final x = normalizeSearchText(extra.join(' '));
      var minP = double.infinity;
      for (final k in packs) {
        if (k.price < minP) minP = k.price;
      }
      items.add(SeItem(
        p: p,
        sh: sh,
        cat: cat,
        n: n,
        b: b,
        c: c,
        s: normalizeSearchText(sh.name),
        x: x,
        sk: skel(taLatin('$n $b $c $x')),
        skN: skel(taLatin(n)),
        minP: minP,
        off: p.packs.any((k) => k.offer != null),
        avail: p.avail,
        packs: packs.map((k) => k.w.trim()).where((w) => w.isNotEmpty).toList(),
        attrs: p.attrs,
      ));
      if (p.brand.isNotEmpty) brands[b] = p.brand;
    }
    final shops = shopBy.values.map((s) {
      final t = S.kindOf(s);
      final n = normalizeSearchText(s.name), d = normalizeSearchText('${s.description} ${t?.n ?? ''} ${s.shopType}');
      return SeShop(s, n, d, skel(taLatin('$n $d')));
    }).toList();
    final seen = <String>{};
    final cats = <SeCat>[];
    for (final c in S.cats) {
      if (c.hidden || !shopBy.containsKey(c.shopId)) continue;
      final n = normalizeSearchText(c.n);
      if (seen.contains(n)) continue;
      if (!items.any((i) => identical(i.cat, c))) continue;
      seen.add(n);
      cats.add(SeCat('cat', c, null, n, normalizeSearchText(c.id), skel(taLatin(n))));
    }
    for (final t in S.kinds) {
      if (t.hide) continue;
      final n = normalizeSearchText(t.n);
      if (seen.contains(n)) continue;
      seen.add(n);
      cats.add(SeCat('kind', null, t, n, normalizeSearchText(t.id), skel(taLatin(n))));
    }
    _ix = SeIndex(items, shops, cats, brands.entries.map((e) => SeBrand(e.key, e.value, skel(taLatin(e.key)))).toList());
    _ver = S.ver;
    return _ix!;
  }

  // ஒரு சொல் × ஒரு field: முழுதும் > தொடக்கம் > சொல்-தொடக்கம் > உள்ளே
  static double seField(String f, String t, double w) {
    if (f.isEmpty || t.isEmpty) return 0;
    if (f == t) return w;
    if (f.startsWith(t)) return w * .85;
    if (' $f'.contains(' $t')) return w * .75;
    if (t.length >= 2 && f.contains(t)) return w * .6;
    return 0;
  }

  static double _max(List<double> l) => l.reduce((a, b) => a > b ? a : b);

  static double scoreItem(SeItem it, List<SeTok> toks) {
    var tot = 0.0;
    for (final k in toks) {
      var s = _max([seField(it.n, k.t, 100), seField(it.b, k.t, 55), seField(it.c, k.t, 40), seField(it.x, k.t, 35), seField(it.s, k.t, 25)]);
      if (k.al.isNotEmpty) s = _max([s, seField(it.n, k.al, 90) * .9, seField(it.c, k.al, 40) * .9, seField(it.b, k.al, 50) * .9]);
      if (s == 0 && k.sk.length >= 3) {
        if (it.skN.startsWith(k.sk) || ' ${it.skN}'.contains(' ${k.sk}')) {
          s = 30;
        } else if (it.sk.contains(k.sk)) {
          s = 20;
        }
      }
      if (s == 0) return 0; // எல்லா சொல்லும் எங்காவது பொருந்த வேண்டும்
      tot += s;
    }
    if (toks.length > 1 && it.n == toks.map((k) => k.t).join(' ')) tot += 50;
    return tot;
  }

  static double km(Shop s) => S.shopKm(s) ?? 1e9;

  static List<SeHit> searchProducts(String q, {String? shopId}) {
    final toks = getSearchTokens(q);
    if (toks.isEmpty) return [];
    final out = <SeHit>[];
    for (final it in index().items) {
      if (shopId != null && it.sh.id != shopId) continue;
      final sc = scoreItem(it, toks);
      if (sc > 0) out.add(SeHit(it, sc));
    }
    out.sort((a, b) {
      int c;
      c = (b.it.avail ? 1 : 0) - (a.it.avail ? 1 : 0);
      if (c != 0) return c;
      c = b.sc.compareTo(a.sc);
      if (c != 0) return c;
      c = (b.it.sh.isOpenNow ? 1 : 0) - (a.it.sh.isOpenNow ? 1 : 0);
      if (c != 0) return c;
      c = (a.it.p.stock == 'low' ? 1 : 0) - (b.it.p.stock == 'low' ? 1 : 0);
      if (c != 0) return c;
      c = km(a.it.sh).compareTo(km(b.it.sh));
      if (c != 0) return c;
      c = a.it.minP.compareTo(b.it.minP);
      if (c != 0) return c;
      c = a.it.n.compareTo(b.it.n);
      if (c != 0) return c;
      return a.it.p.key.compareTo(b.it.p.key);
    });
    return out;
  }

  static bool seSkWord(String sk, String q) {
    if (sk.isEmpty || q.isEmpty) return false;
    return sk.split(' ').any((w) => w == q || (w.startsWith(q) && q.length >= w.length * .6));
  }

  static double seMatchText(String n, String sk, List<SeTok> toks) {
    var tot = 0.0;
    for (final k in toks) {
      var s = seField(n, k.t, 100);
      if (k.al.isNotEmpty) s = _max([s, seField(n, k.al, 90)]);
      if (s == 0 && k.sk.isNotEmpty && seSkWord(sk, k.sk)) s = 30;
      if (s == 0) return 0;
      tot += s;
    }
    return tot;
  }

  static List<Shop> searchShops(String q) {
    final toks = getSearchTokens(q);
    if (toks.isEmpty) return [];
    final r = index()
        .shops
        .map((x) => MapEntry(x.sh, _max([seMatchText(x.n, x.sk, toks), seMatchText(x.d, '', toks) * .5])))
        .where((e) => e.value > 0)
        .toList();
    r.sort((a, b) {
      var c = b.value.compareTo(a.value);
      if (c != 0) return c;
      c = km(a.key).compareTo(km(b.key));
      if (c != 0) return c;
      return a.key.name.compareTo(b.key.name);
    });
    return r.map((e) => e.key).toList();
  }

  static List<SeCat> searchCategories(String q) {
    final toks = getSearchTokens(q);
    if (toks.isEmpty) return [];
    final r = index()
        .cats
        .map((x) => MapEntry(x, _max([seMatchText(x.n, x.sk, toks), seMatchText(x.id, '', toks) * .9])))
        .where((e) => e.value > 0)
        .toList();
    r.sort((a, b) => b.value.compareTo(a.value));
    return r.map((e) => e.key).toList();
  }

  // பரிந்துரைகள்: g = p(பொருள்) c(வகை) k(கடை வகை) b(பிராண்ட்) s(கடை)
  static List<Map<String, String>> suggestions(String q) {
    final toks = getSearchTokens(q);
    if (toks.isEmpty) return [];
    final out = <Map<String, String>>[];
    final seen = <String>{};
    for (final r in searchProducts(q)) {
      final key = '${r.it.n}|${r.it.b}';
      if (seen.contains(key) || out.where((o) => o['g'] == 'p').length >= 4) continue;
      seen.add(key);
      out.add({
        'g': 'p',
        'label': (r.it.p.brand.isNotEmpty && !r.it.n.contains(r.it.b) ? '${r.it.p.brand} ' : '') + r.it.p.name,
        'q': r.it.p.name,
        'img': r.it.p.photo,
        'e': r.it.p.emoji,
      });
    }
    for (final c in searchCategories(q).take(2)) {
      out.add(c.type == 'cat'
          ? {'g': 'c', 'label': c.c!.n, 'q': c.c!.n, 'e': c.c!.e.isNotEmpty ? c.c!.e : '🏷️', 'img': ''}
          : {'g': 'k', 'label': c.t!.n, 'id': c.t!.id, 'e': c.t!.e, 'img': ''});
    }
    final br = index().brands.where((b) => toks.every((k) => b.n.contains(k.t) || (k.sk.isNotEmpty && b.sk.contains(k.sk)))).take(1);
    for (final b in br) {
      out.add({'g': 'b', 'label': b.label, 'q': b.label, 'e': '🏷️', 'img': ''});
    }
    for (final s in searchShops(q).take(2)) {
      out.add({'g': 's', 'label': s.name, 'id': s.id, 'e': '🏪', 'img': ''});
    }
    return out.take(8).toList();
  }

  static int lev(String a, String b) {
    if ((a.length - b.length).abs() > 2) return 9;
    final d = List.generate(a.length + 1, (i) => List<int>.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) {
      d[i][0] = i;
    }
    for (var j = 1; j <= b.length; j++) {
      d[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final x = d[i - 1][j] + 1, y = d[i][j - 1] + 1, z = d[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
        d[i][j] = x < y ? (x < z ? x : z) : (y < z ? y : z);
      }
    }
    return d[a.length][b.length];
  }

  // "இதைத் தேடினீர்களா?"
  static List<String> didYouMean(String q) {
    final nq = normalizeSearchText(q);
    if (nq.length < 3) return [];
    final sq = _tamil.hasMatch(nq) ? skel(taLatin(nq)) : skel(nq);
    final ix = index();
    final cand = <String, String>{};
    for (final it in ix.items) {
      cand[it.p.name] = it.skN;
      if (it.p.brand.isNotEmpty) cand[it.p.brand] = skel(taLatin(it.b));
    }
    for (final c in ix.cats) {
      cand[c.label] = c.sk;
    }
    final lim = (sq.length / 4).floor() > 1 ? (sq.length / 4).floor() : 1;
    final r = cand.entries.where((e) => normalizeSearchText(e.key) != nq).map((e) => MapEntry(e.key, lev(sq, e.value))).where((x) => x.value <= lim).toList();
    r.sort((a, b) {
      final c = a.value.compareTo(b.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
    return r.take(3).map((e) => e.key).toList();
  }

  // தொடர்புடைய பொருட்கள் (உண்மைப் பொருட்கள் மட்டும்)
  static List<Product> related(String q) {
    final toks = getSearchTokens(q);
    final seen = <String>{};
    final out = <Product>[];
    void add(List<SeHit> rs) {
      for (final r in rs) {
        if (out.length < 8 && seen.add(r.it.p.key)) out.add(r.it.p);
      }
    }

    if (toks.length > 1) {
      for (final t in toks) {
        add(searchProducts(t.t));
      }
    }
    if (out.isEmpty) {
      final n = normalizeSearchText(q);
      if (n.length >= 3) {
        final len = (n.length / 2).ceil() > 2 ? (n.length / 2).ceil() : 2;
        add(searchProducts(n.substring(0, len > n.length ? n.length : len)));
      }
    }
    return out;
  }

  static List<Shop> nearShops([int n = 4]) {
    final l = index().shops.map((x) => x.sh).toList();
    l.sort((a, b) {
      final c = (b.isOpenNow ? 1 : 0) - (a.isOpenNow ? 1 : 0);
      return c != 0 ? c : km(a).compareTo(km(b));
    });
    return l.take(n).toList();
  }

  // பரிந்துரைக்கப்படும் தேடல்கள்: இந்த phone-ன் பழைய ஆர்டர்கள் → பல கடைகளில் உள்ளவை → சலுகைகள்
  static List<String> popular() {
    final out = <String>[];
    final seen = <String>{};
    void add(String n) {
      final k = normalizeSearchText(n);
      if (k.isNotEmpty && !seen.contains(k) && out.length < 8) {
        seen.add(k);
        out.add(n);
      }
    }

    final ix = index();
    final have = ix.items.map((i) => i.n).toSet();
    for (final o in S.ordLocal()) {
      final its = o['its'];
      if (its is List) {
        for (final i in its) {
          if (i is Map && js(i['n']).isNotEmpty && have.contains(normalizeSearchText(i['n']))) add(js(i['n']));
        }
      }
    }
    final by = <String, MapEntry<String, Set<String>>>{};
    for (final i in ix.items) {
      by.putIfAbsent(i.n, () => MapEntry(i.p.name, <String>{})).value.add(i.sh.id);
    }
    final l = by.values.toList()
      ..sort((a, b) {
        final c = b.value.length.compareTo(a.value.length);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    for (final x in l) {
      if (x.value.length > 1) add(x.key);
    }
    for (final i in ix.items.where((i) => i.off)) {
      add(i.p.name);
    }
    return out;
  }

  // ── வடிகட்டல் ──
  static bool _fast(SeItem it) => jz(it.sh.m['delivery_max']) > 0 && jz(it.sh.m['delivery_max']) <= kSrFastMin;
  static bool _rate(SeItem it) => (S.shopRating(it.sh) ?? 0) >= 4;

  static AvailF availableFilters(List<SeHit> rs) {
    final f = AvailF();
    Map<String, int> cnt(Iterable<String> arr) {
      final m = <String, int>{};
      for (final x in arr) {
        if (x.isNotEmpty) m[x] = (m[x] ?? 0) + 1;
      }
      return m;
    }

    final sh = cnt(rs.map((r) => r.it.sh.id));
    if (sh.length > 1) f.shop = sh.keys.map((id) => FOpt(id, S.shopById(id)?.name ?? id, sh[id]!)).toList();
    final ca = cnt(rs.map((r) => r.it.cat?.n ?? ''));
    if (ca.length > 1) f.cat = (ca.keys.toList()..sort((a, b) => ca[b]!.compareTo(ca[a]!))).take(12).map((v) => FOpt(v, v, ca[v]!)).toList();
    final br = cnt(rs.map((r) => r.it.p.brand));
    if (br.length > 1) f.brand = (br.keys.toList()..sort((a, b) => br[b]!.compareTo(br[a]!))).take(14).map((v) => FOpt(v, v, br[v]!)).toList();
    final pk = cnt(rs.expand((r) => r.it.packs));
    if (pk.length > 1) f.pack = (pk.keys.toList()..sort((a, b) => packWeightVal(a).compareTo(packWeightVal(b)))).take(14).map((v) => FOpt(v, v, pk[v]!)).toList();
    final pb = <FOpt>[];
    for (var i = 0; i < kPriceBuckets.length; i++) {
      final b = kPriceBuckets[i];
      final n = rs.where((r) => r.it.minP >= b[0] && r.it.minP < b[1]).length;
      if (n > 0) pb.add(FOpt('$i', seBucketLabel(b), n));
    }
    if (pb.length > 1) f.price = pb;
    bool split(bool Function(SeHit) fn) => rs.any(fn) && rs.any((r) => !fn(r));
    final q = <List<String>>[];
    if (split((r) => r.it.off)) q.add(['offer', '🏷️ சலுகை']);
    if (rs.any((r) => S.shopKm(r.it.sh) != null) && split((r) => km(r.it.sh) <= kSrNearKm)) q.add(['near', '📍 அருகில் (${kSrNearKm.toInt()} km)']);
    if (split((r) => r.it.avail)) q.add(['avail', '✅ கையிருப்பு உள்ளது']);
    if (split((r) => _fast(r.it))) q.add(['fast', '🛵 விரைவு டெலிவரி']);
    if (split((r) => _rate(r.it))) q.add(['rate', '⭐ 4+ மதிப்பீடு']);
    if (split((r) => r.it.sh.isOpenNow)) q.add(['open', '🟢 திறந்துள்ளது']);
    if (q.isNotEmpty) f.quick = q;
    final ak = <String, Map<String, int>>{};
    for (final r in rs) {
      r.it.attrs.forEach((k, v) {
        final m = ak.putIfAbsent(k, () => {});
        m[v] = (m[v] ?? 0) + 1;
      });
    }
    final at = ak.keys.where((k) => ak[k]!.length > 1).take(6).toList();
    if (at.isNotEmpty) {
      f.attr = at.map((k) {
        final vs = ak[k]!.keys.toList()..sort();
        return AttrF(k, vs.take(14).map((v) => FOpt(v, v, ak[k]![v]!)).toList());
      }).toList();
    }
    return f;
  }

  static List<SeHit> applyFilters(List<SeHit> rs, SrF F) {
    return rs.where((r) {
      final it = r.it;
      if (F.shop.isNotEmpty && !F.shop.contains(it.sh.id)) return false;
      if (F.cat.isNotEmpty && !F.cat.contains(it.cat?.n ?? '')) return false;
      if (F.brand.isNotEmpty && !F.brand.contains(it.p.brand)) return false;
      if (F.pack.isNotEmpty && !it.packs.any((w) => F.pack.contains(w))) return false;
      if (F.price != '') {
        final i = int.tryParse(F.price);
        if (i != null && i >= 0 && i < kPriceBuckets.length) {
          final b = kPriceBuckets[i];
          if (!(it.minP >= b[0] && it.minP < b[1])) return false;
        }
      }
      if (F.offer && !it.off) return false;
      if (F.open && !it.sh.isOpenNow) return false;
      if (F.near && !(km(it.sh) <= kSrNearKm)) return false;
      if (F.avail && !it.avail) return false;
      if (F.fast && !_fast(it)) return false;
      if (F.rate && !_rate(it)) return false;
      for (final e in F.attr.entries) {
        if (e.value.isNotEmpty && !e.value.contains(it.attrs[e.key])) return false;
      }
      return true;
    }).toList();
  }

  static List<List<String>> sortOptions(List<SeHit> rs) {
    final o = [
      ['rel', 'பொருத்தமானவை'],
      ['plh', 'விலை: குறைவு → அதிகம்'],
      ['phl', 'விலை: அதிகம் → குறைவு'],
    ];
    if (rs.any((r) => S.shopKm(r.it.sh) != null)) o.add(['near', 'அருகிலுள்ள கடை']);
    if (rs.any((r) => jz(r.it.sh.m['delivery_min']) > 0)) o.add(['fast', 'விரைவான டெலிவரி']);
    if (rs.any((r) => S.shopRating(r.it.sh) != null)) o.add(['rate', 'கடை மதிப்பீடு']);
    if (rs.any((r) => r.it.p.createdAt.isNotEmpty)) o.add(['new', 'புதியவை']);
    return o;
  }

  static List<SeHit> sortResults(List<SeHit> rs, String mode) {
    final a = List.of(rs);
    int tie(SeHit x, SeHit y) {
      var c = y.sc.compareTo(x.sc);
      if (c != 0) return c;
      c = x.it.minP.compareTo(y.it.minP);
      if (c != 0) return c;
      return x.it.p.key.compareTo(y.it.p.key);
    }

    int then(int c, SeHit x, SeHit y) => c != 0 ? c : tie(x, y);
    double dm(SeHit x) => jz(x.it.sh.m['delivery_min']) > 0 ? jz(x.it.sh.m['delivery_min']) : 999;
    int ts(SeHit x) => DateTime.tryParse(x.it.p.createdAt)?.millisecondsSinceEpoch ?? 0;
    if (mode == 'plh') {
      a.sort((x, y) => then(x.it.minP.compareTo(y.it.minP), x, y));
    } else if (mode == 'phl') {
      a.sort((x, y) => then(y.it.minP.compareTo(x.it.minP), x, y));
    } else if (mode == 'near') {
      a.sort((x, y) => then(km(x.it.sh).compareTo(km(y.it.sh)), x, y));
    } else if (mode == 'fast') {
      a.sort((x, y) => then(dm(x).compareTo(dm(y)), x, y));
    } else if (mode == 'rate') {
      a.sort((x, y) => then((S.shopRating(y.it.sh) ?? 0).compareTo(S.shopRating(x.it.sh) ?? 0), x, y));
    } else if (mode == 'new') {
      a.sort((x, y) => then(ts(y).compareTo(ts(x)), x, y));
    }
    return a;
  }

  // ஒரே பொருள் (brand + பெயர்) பல கடைகளில் → ஒரே card
  static List<List<SeHit>> group(List<SeHit> rs) {
    final g = <String, List<SeHit>>{};
    for (final r in rs) {
      g.putIfAbsent('${r.it.b}|${r.it.n}', () => []).add(r);
    }
    return g.values.toList();
  }
}

// ── தேடல் வரலாறு (இந்த phone மட்டும்) ──
class SrHist {
  static List<String> get() {
    final a = Store.json(K.srchHist);
    if (a is! List) return [];
    return a.whereType<String>().take(8).toList();
  }

  static void add(String q0) {
    var q = q0.trim();
    if (q.length > 60) q = q.substring(0, 60);
    if (q.length < 2) return;
    final a = get().where((x) => x.toLowerCase() != q.toLowerCase()).toList();
    a.insert(0, q);
    Store.setJson(K.srchHist, a.take(8).toList());
  }

  static void del(int i) {
    final a = get();
    if (i >= 0 && i < a.length) a.removeAt(i);
    Store.setJson(K.srchHist, a);
  }

  static void clear() => Store.remove(K.srchHist);
}
