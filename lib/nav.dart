// Crispy — திரைகளுக்கு இடையே செல்லுதல் + Android back பட்டன் விதிகள்
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'screens/cart.dart';
import 'screens/product_sheet.dart';
import 'screens/shops.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

class Nav {
  static final GlobalKey<NavigatorState> root = GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> inner = GlobalKey<NavigatorState>();

  // home · shops · orders · cart
  static final ValueNotifier<String> tab = ValueNotifier('home');
  // கடைகள் tab-ல் தேர்ந்த வகை ('' = எல்லாம்)
  static final ValueNotifier<String> shopsType = ValueNotifier('');
  // உள் திரைகளின் எண்ணிக்கை (கடை / கடை விவரம் ...)
  static final ValueNotifier<int> depth = ValueNotifier(0);
  // home தேடல் போன்ற "உள் நிலைகள்" — back அழுத்தினால் முதலில் இவை மூடும்
  static final List<VoidCallback> backHandlers = [];
  // முகப்பு திரையை மேலே scroll / தேடல் மூட
  static final ValueNotifier<int> homeReset = ValueNotifier(0);
  // கடைகள் tab: தேடல் எழுத்து + வரிசையை அழி (HTML pickType: homeQ='', homeSort='')
  static final ValueNotifier<int> shopsReset = ValueNotifier(0);
  // முகப்பின் "சலுகைகள்" பகுதி (வெளியேறும் sheet → அங்கே scroll)
  static final GlobalKey dealsKey = GlobalKey();
  // HTML _navFrom: ஆர்டர்கள் / கூடை tab-லிருந்து back → வந்த முகப்பு நிலைக்கு (முகப்பு / கடைகள்)
  static String? _from;

  static AppState get S => AppState.I;
  static BuildContext? get ctx => root.currentState?.overlay?.context ?? root.currentContext;

  static DateTime _lastBack = DateTime.fromMillisecondsSinceEpoch(0);

  static void popInnerToRoot() {
    final n = inner.currentState;
    if (n != null) n.popUntil((r) => r.isFirst);
  }

  // navGo: எல்லா உள் திரைகளையும் மூடி அந்த tab-க்கு
  static void go(String t) {
    final cur = tab.value;
    if (t == 'orders' || t == 'cart') {
      _from = (cur == 'home' || cur == 'shops') && (innerHl.value == null) ? cur : null;
    } else {
      _from = null;
    }
    backHandlers.clear();
    popInnerToRoot();
    if (t == 'shops') shopsType.value = ''; // HTML navGo('shops'): homeType=''
    if (t == 'home') homeReset.value++;
    tab.value = t;
  }

  // hl: கீழ் பட்டையில் எந்த tab ஒளிர வேண்டும்
  static Future<T?> push<T>(Widget page, {String hl = 'shops'}) {
    final n = inner.currentState;
    if (n == null) return Future.value(null);
    return n.push<T>(MaterialPageRoute(builder: (_) => page, settings: RouteSettings(name: hl)));
  }

  // கீழ் பட்டையில் ஒளிரும் tab (உள் திரை இருந்தால் அதன் hl)
  static final ValueNotifier<String?> innerHl = ValueNotifier(null);

  // கடைக்குள் செல் (வகை / பொருள் நேராக)
  static void openShop(String shopId, {String? cat, String? prodKey}) {
    S.setActiveShop(shopId);
    push(ShopScreen(shopId: shopId, initialCat: cat, jumpProd: prodKey));
  }

  static void openShopDetail(String shopId) => push(ShopDetailScreen(shopId: shopId));

  // "மற்ற கடைகளில் கிடைக்கிறது": இப்போதைய கடையை மாற்று (அடுக்காதே)
  static void replaceShop(String shopId) {
    S.setActiveShop(shopId);
    final n = inner.currentState;
    if (n == null) return;
    final page = MaterialPageRoute(builder: (_) => ShopScreen(shopId: shopId), settings: const RouteSettings(name: 'shops'));
    if (n.canPop()) {
      n.pushReplacement(page);
    } else {
      n.push(page);
    }
  }

  // HTML openCart: கடைக்குள் இருந்தால் அதன் மேலே கூடை (back → கடைக்குத் திரும்பும்)
  static void openCart() {
    final n = inner.currentState;
    if (n != null && n.canPop()) {
      push(const CartScreen(), hl: 'cart');
    } else {
      go('cart');
    }
  }

  // HTML goBack(closeCart) / கூடை·ஆர்டர்கள் மூடு: முந்தைய திரைக்கு
  static void leave() {
    final n = inner.currentState;
    if (n != null && n.canPop()) {
      n.pop();
      return;
    }
    final m = _from;
    _from = null;
    go(m ?? 'home');
  }

  // HTML openShops: கடைகள் tab, வகை இல்லாமல்
  static void openShops() => go('shops');

  // home வகை → கடைகள் tab (ஒரே கடை என்றால் நேராக உள்ளே)
  static void pickType(String id) {
    final list = S.visibleShops.where((x) => S.shopType(x) == id).toList();
    if (list.isEmpty) {
      toast('🕒 இந்த வகையில் கடைகள் விரைவில் வரும்');
      return;
    }
    if (list.length == 1) {
      openShop(list.first.id);
      return;
    }
    backHandlers.clear();
    popInnerToRoot();
    _from = null;
    shopsType.value = id;
    shopsReset.value++;
    tab.value = 'shops';
  }

  // home தேடல் முடிவு → பொருள் உள்ள கடை, அந்த வகை, அந்தப் பொருள்
  static void goProd(Product p) => openShop(p.shopId, cat: p.category, prodKey: p.key);

  static Future<void> openProduct(Product p) async {
    final c = ctx;
    if (c == null || p.packs.isEmpty) return;
    await showProductSheet(c, p);
  }

  // Android back
  static Future<void> back() async {
    final now = DateTime.now();
    if (now.difference(_lastBack).inMilliseconds < 350) return; // தவறுதலான இரட்டைத் தட்டு
    _lastBack = now;
    final n = inner.currentState;
    if (n != null && n.canPop()) {
      await n.maybePop(); // திரை தன் உள் நிலையை முதலில் மூடலாம் (PopScope)
      return;
    }
    if (backHandlers.isNotEmpty) {
      final f = backHandlers.removeLast();
      f();
      return;
    }
    if (tab.value != 'home') {
      final m = (tab.value == 'orders' || tab.value == 'cart') ? _from : null;
      _from = null;
      go(m ?? 'home');
      return;
    }
    final c = ctx;
    if (c == null) return;
    final out = await showExitSheet(c);
    if (out == true) SystemNavigator.pop();
  }
}

// கூடையில் பொருள் இருந்தால் / சலுகை இருந்தால் "இப்போதே போகிறீர்களா?"
Future<bool?> showExitSheet(BuildContext context) {
  final s = AppState.I;
  final n = s.cartCount;
  final deals = s.prods.any((p) => !p.hidden && p.packs.any((k) => k.offer != null));
  String t, sub, cta;
  VoidCallback fn;
  if (n > 0) {
    t = 'கூடையில் பொருட்கள் காத்திருக்கின்றன!';
    sub = 'உங்கள் கூடையில் $n ${n == 1 ? 'பொருள்' : 'பொருட்கள்'} உள்ளன — ஆர்டரை முடித்துவிடலாமா?';
    cta = 'கூடையைப் பார்';
    fn = () => Nav.go('cart');
  } else if (deals) {
    t = 'இப்போதே போகிறீர்களா?';
    sub = 'அருகிலுள்ள கடைகளில் இன்றைய சலுகைகள் உள்ளன!';
    cta = 'சலுகைகளைப் பார்';
    fn = () {
      Nav.go('home');
      // HTML exitShowDeals: சலுகைகள் பகுதிக்கு scroll
      Future.delayed(const Duration(milliseconds: 400), () {
        final c = Nav.dealsKey.currentContext;
        if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      });
    };
  } else {
    t = 'இப்போதே போகிறீர்களா?';
    sub = 'உங்கள் ஊர் கடைகள் எப்போதும் இங்கே திறந்திருக்கும்!';
    cta = 'கடைகளைப் பார்';
    fn = () => Nav.go('shops');
  }
  // படங்கள்: கடைப் படங்கள் → வகைப் படங்கள் → emoji
  final pics = <List<String>>[];
  void add(String img, String e, String bg) {
    if (pics.length < 5) pics.add([img, e, bg]);
  }

  for (final x in s.visibleShops) {
    if (x.coverImage.isNotEmpty || x.logoImage.isNotEmpty) add(x.coverImage.isNotEmpty ? x.coverImage : x.logoImage, '🏪', '#e3f3e6');
  }
  for (final k in s.kinds.where((k) => !k.hide)) {
    if (s.kindImg[k.id] != null) add(s.kindImg[k.id]!.replaceAll(RegExp(r'#cut$'), ''), k.e, s.kindBg(k));
  }
  for (final k in s.kinds.where((k) => !k.hide)) {
    add('', k.e, s.kindBg(k));
  }
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (c) => Container(
      decoration: BoxDecoration(color: P.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
      padding: EdgeInsets.fromLTRB(22, 26, 22, 18 + MediaQuery.of(c).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 110,
          child: Stack(alignment: Alignment.center, children: [
            for (var i = 0; i < pics.length; i++)
              Transform.translate(
                offset: Offset((i - (pics.length - 1) / 2) * 46.0, (i - (pics.length - 1) / 2).abs() * 8),
                child: Transform.rotate(
                  angle: (i - (pics.length - 1) / 2) * 0.16,
                  child: Container(
                    width: 78,
                    height: 96,
                    decoration: BoxDecoration(
                      color: hexColor(pics[i][2]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: P.card, width: 3),
                      boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4))],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: pics[i][0].isNotEmpty
                        ? Img(pics[i][0], emoji: pics[i][1], fit: BoxFit.cover)
                        : Center(child: Text(pics[i][1], style: const TextStyle(fontSize: 34))),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Text(t, textAlign: TextAlign.center, style: ts(19, w: w8)),
        const SizedBox(height: 6),
        Text(sub, textAlign: TextAlign.center, style: ts(14, c: P.mu2, h: 1.45)),
        const SizedBox(height: 18),
        GreenButton(cta, onTap: () {
          Navigator.pop(c, false);
          fn();
        }),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text('Crispy-லிருந்து வெளியேறு', style: ts(14, w: w7, c: P.mu2)),
        ),
      ]),
    ),
  );
}
