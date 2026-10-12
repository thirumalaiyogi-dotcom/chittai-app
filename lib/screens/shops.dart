// சிட்டை — கடைகள் tab, கடை விவரம் (Google Business பாணி), கடைக்குள் (வகைகள் + பொருட்கள்)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';
import 'home.dart';
import 'search.dart';

// ═══ கடைகள் tab: வகை tabs (மேலே ஒட்டிக்கொள்ளும்) + கடைத் தேடல் + பட்டியல் ═══
class ShopsTab extends StatefulWidget {
  const ShopsTab({super.key});
  @override
  State<ShopsTab> createState() => _ShopsTabState();
}

class _ShopsTabState extends State<ShopsTab> {
  final _q = TextEditingController();
  final _f = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    TypingHint.attach();
    _f.addListener(() => setState(() {}));
    Nav.shopsReset.addListener(_rst);
  }

  // HTML pickType: homeQ='' (கடைத் தேடல் எழுத்தை அழி)
  void _rst() {
    if (!mounted) return;
    _q.clear();
    setState(() => _query = '');
  }

  @override
  void dispose() {
    Nav.shopsReset.removeListener(_rst);
    TypingHint.detach();
    _q.dispose();
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final vis = s.visibleShops;
    final kinds = s.kinds.where((t) => !t.hide).map((t) => MapEntry(t, vis.where((x) => s.shopType(x) == t.id).length)).where((e) => e.value > 0).toList();
    final multi = kinds.length > 1;
    return ValueListenableBuilder<String>(
      valueListenable: Nav.shopsType,
      builder: (_, type0, __) {
        var type = type0;
        if (!multi || !kinds.any((k) => k.key.id == type)) type = '';
        return Scaffold(
          backgroundColor: P.bg,
          body: Column(children: [
            const AppHeader(),
            Expanded(
              child: RefreshIndicator(
                color: P.g,
                onRefresh: () => s.runCloudLoad(),
                child: CustomScrollView(slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(gradient: kHeroGrad, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('கடைகள்', style: ts(22, w: w8, c: Colors.white)),
                        Container(
                          height: 52,
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.only(left: 14, right: 6),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                          child: Row(children: [
                            const Icon(Icons.search, color: Color(0xFF00A884)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ValueListenableBuilder<String>(
                                valueListenable: TypingHint.shop,
                                builder: (_, hint, __) => TextField(
                                  controller: _q,
                                  focusNode: _f,
                                  onChanged: (v) => setState(() => _query = v),
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => _f.unfocus(),
                                  style: ts(16, w: w6, c: const Color(0xFF17201D)),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: _f.hasFocus ? 'கடையைத் தேடுங்கள்...' : hint,
                                    hintStyle: ts(15, w: w6, c: const Color(0xFF87938F)),
                                  ),
                                ),
                              ),
                            ),
                            if (_query.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close, size: 20, color: Color(0xFF5D6B68)),
                                onPressed: () {
                                  _q.clear();
                                  setState(() => _query = '');
                                },
                              ),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                  if (multi)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _KindTabs(kinds.map((e) => e.key).toList(), type, s.dark),
                    ),
                  SliverToBoxAdapter(child: ShopList(type: type, query: _query)),
                  const SliverToBoxAdapter(child: SizedBox(height: 60)),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _KindTabs extends SliverPersistentHeaderDelegate {
  final List<Kind> kinds;
  final String on;
  final bool dark;
  _KindTabs(this.kinds, this.on, this.dark);

  @override
  double get minExtent => 104;
  @override
  double get maxExtent => 104;
  @override
  bool shouldRebuild(covariant _KindTabs o) => o.on != on || o.kinds.length != kinds.length || o.dark != dark;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    Widget tab(String id, bool a, Widget circle, String nm) => GestureDetector(
          onTap: () => Nav.shopsType.value = id,
          child: Container(
            width: 84,
            padding: const EdgeInsets.only(top: 12),
            child: Stack(children: [
              Column(children: [
                AnimatedScale(scale: a ? 1.04 : 1, duration: const Duration(milliseconds: 150), child: circle),
                const SizedBox(height: 6),
                Text(nm, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12.5, w: a ? w8 : w7, c: a ? P.text : P.mu2)),
              ]),
              if (a)
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 0,
                  child: Container(height: 3.5, decoration: BoxDecoration(color: P.g, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))),
                ),
            ]),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: P.card,
        border: Border(bottom: BorderSide(color: P.bd)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 6), children: [
        tab(
          '',
          on.isEmpty,
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: P.gc, shape: BoxShape.circle, boxShadow: [if (on.isEmpty) BoxShadow(color: P.g, spreadRadius: 2.5)]),
            child: Icon(Icons.storefront_outlined, color: P.g2, size: 26),
          ),
          'எல்லாம்',
        ),
        for (final k in kinds) tab(k.id, on == k.id, KindCircle(k, size: 52, ring: on == k.id), k.n),
      ]),
    );
  }
}

// ═══ கடை விவரம் ═══
class ShopDetailScreen extends StatelessWidget {
  final String shopId;
  const ShopDetailScreen({super.key, required this.shopId});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = st.shopById(shopId);
    if (s == null) return const Scaffold(body: SizedBox.shrink());
    final kt = st.kindOf(s);
    final r = st.shopRating(s);
    final pn = s.phone.replaceAll(RegExp(r'\D'), '');
    final tel = pn.length >= 10 ? (pn.length == 10 ? '+91$pn' : '+$pn') : '';
    final wn = pn.length == 10 ? '91$pn' : pn;
    final map = shopMapUrl(s);
    final web = RegExp(r'^https?://', caseSensitive: false).hasMatch(s.website) ? s.website : '';
    final webHost = web.replaceFirst(RegExp(r'^https?://(www\.)?', caseSensitive: false), '').replaceFirst(RegExp(r'/.*$'), '');
    final acts = <Widget>[
      if (tel.isNotEmpty) _act(Icons.call_outlined, 'அழை', () => openUrl('tel:$tel')),
      if (map.isNotEmpty) _act(Icons.directions_outlined, 'வழி', () => openUrl(map)),
      if (wn.length >= 11) _act(Icons.chat_outlined, 'WhatsApp', () => openUrl('https://wa.me/$wn')),
      if (web.isNotEmpty) _act(Icons.language, 'இணையதளம்', () => openUrl(web)),
    ];
    final rows = <Widget>[];
    void row(IconData ic, String main, String sub, {VoidCallback? onTap, Widget? subW}) {
      rows.add(InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: P.bd))),
          child: Row(children: [
            Icon(ic, color: P.g2, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(main, style: ts(14.5, w: w7, h: 1.45)),
                if (subW != null) subW else if (sub.isNotEmpty) Text(sub, style: ts(12.5, w: w6, c: P.mu)),
              ]),
            ),
          ]),
        ),
      ));
    }

    if (s.openingTime.isNotEmpty && s.closingTime.isNotEmpty) {
      row(Icons.schedule, '${tTime(s.openingTime)} – ${tTime(s.closingTime)}', '', subW: OpenLine(s));
    }
    final dist = st.shopDistText(s);
    if (s.address.isNotEmpty || map.isNotEmpty) {
      row(Icons.place_outlined, s.address.isNotEmpty ? s.address : 'வரைபடத்தில் பார்க்க', dist.isNotEmpty ? '$dist தூரம்' : '', onTap: map.isNotEmpty ? () => openUrl(map) : null);
    }
    if (tel.isNotEmpty) row(Icons.call_outlined, s.phone, 'அழைக்க தொடுங்கள்', onTap: () => openUrl('tel:$tel'));
    if (web.isNotEmpty) row(Icons.language, webHost, 'இணையதளம்', onTap: () => openUrl(web));
    if (!s.deliveryAvailable) {
      row(Icons.local_shipping_outlined, 'டெலிவரி இல்லை', '');
    } else {
      final x = s.feeText;
      if (jz(s.m['min_order']) > 0) x.add('குறைந்தபட்சம் ₹${rupee(s.m['min_order'])}');
      row(Icons.local_shipping_outlined, s.etaKnown ? '${s.etaText} நிமிடத்தில் டெலிவரி' : 'டெலிவரி உண்டு', x.join(' · '));
    }

    return Scaffold(
      backgroundColor: P.bg,
      appBar: AppBar(
        backgroundColor: P.card,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: P.text), onPressed: () => Navigator.of(context).maybePop()),
        title: Text('கடை விவரம்', style: ts(18, w: w8)),
      ),
      body: Stack(children: [
        ListView(padding: const EdgeInsets.only(bottom: 100), children: [
          SizedBox(
            height: 224,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                height: 180,
                width: double.infinity,
                color: kt != null ? hexColor(st.kindBg(kt)) : P.gc,
                child: s.coverImage.isNotEmpty ? Img(s.coverImage, emoji: kt?.e ?? '🏪') : null,
              ),
              Positioned(
                left: 16,
                top: 136,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: P.card, width: 4),
                    boxShadow: const [BoxShadow(color: Color(0x24000000), blurRadius: 18, offset: Offset(0, 6))],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: s.logoImage.isNotEmpty ? Img(s.logoImage, emoji: kt?.e ?? '🏪') : Center(child: Text(s.logoEmoji(kt?.e ?? '🏪'), style: const TextStyle(fontSize: 42))),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, style: ts(22, w: w8)),
              const SizedBox(height: 4),
              Text.rich(TextSpan(style: ts(13.5, w: w7, c: P.mu2), children: [
                TextSpan(text: kt?.n ?? ''),
                if (r != null) ...[
                  const TextSpan(text: ' · '),
                  TextSpan(text: '★ ${r.toStringAsFixed(1)}', style: ts(13.5, w: w8, c: const Color(0xFFE08A00))),
                  if (st.shopReviewCount(s) > 0) TextSpan(text: ' (${st.shopReviewCount(s)})'),
                ],
              ])),
              if (s.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(s.description, style: ts(13.5, c: P.mu2, h: 1.5))),
              const SizedBox(height: 8),
              OpenLine(s, big: true),
            ]),
          ),
          if (acts.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(12, 16, 12, 6), child: Row(children: acts)),
          if (s.offerText.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFFFF3E8), borderRadius: BorderRadius.circular(12)),
              child: Text('🏷️ ${s.offerText}', style: ts(13, w: w8, c: const Color(0xFFC2410C))),
            ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            decoration: BoxDecoration(color: P.card, border: Border.all(color: P.bd), borderRadius: BorderRadius.circular(18)),
            clipBehavior: Clip.antiAlias,
            child: Column(children: rows),
          ),
          if (r != null) RatingSection(s),
        ]),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: GreenButton('கடைக்குள் செல்ல →', onTap: () {
            Navigator.of(context).pop();
            Nav.openShop(s.id);
          }),
        ),
      ]),
    );
  }

  Widget _act(IconData ic, String l, VoidCallback f) => Expanded(
        child: InkWell(
          onTap: f,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: P.gc, shape: BoxShape.circle),
                child: Icon(ic, color: P.g2, size: 22),
              ),
              const SizedBox(height: 6),
              Text(l, style: ts(12.5, w: w8, c: P.g2)),
            ]),
          ),
        ),
      );
}

String shopMapUrl(Shop s) {
  if (RegExp(r'^https://', caseSensitive: false).hasMatch(s.mapUrl)) return s.mapUrl;
  if (s.lat != null && s.lng != null) return 'https://www.google.com/maps/search/?api=1&query=${s.lat},${s.lng}';
  if (s.address.isNotEmpty) return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${s.name}, ${s.address}')}';
  return '';
}

// "திறந்துள்ளது · இரவு 9:00-க்கு மூடும்"
class OpenLine extends StatelessWidget {
  final Shop s;
  final bool big;
  const OpenLine(this.s, {super.key, this.big = false});
  @override
  Widget build(BuildContext context) {
    final open = s.isOpenNow;
    const on = Color(0xFF188038), off = Color(0xFFD93025);
    final base = ts(big ? 14 : 12.5, w: w6, c: P.mu2);
    InlineSpan b(String t, bool g) => TextSpan(text: t, style: base.copyWith(fontWeight: w8, color: g ? on : off));
    List<InlineSpan> sp;
    if (!s.isOpenFlag) {
      sp = [b('தற்போது மூடப்பட்டுள்ளது', false)];
    } else if (s.openingTime.isEmpty || s.closingTime.isEmpty) {
      sp = [b(open ? 'திறந்துள்ளது' : 'மூடப்பட்டுள்ளது', open)];
    } else {
      sp = open
          ? [b('திறந்துள்ளது', true), TextSpan(text: ' · ${tTime(s.closingTime)}-க்கு மூடும்')]
          : [b('மூடியுள்ளது', false), TextSpan(text: ' · ${tTime(s.openingTime)}-க்கு திறக்கும்')];
    }
    return Text.rich(TextSpan(style: base, children: sp));
  }
}

// ⭐ மதிப்பீடுகள் பகுதி (review_summary)
class RatingSection extends StatelessWidget {
  final Shop s;
  const RatingSection(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final st = AppState.I;
    final r = st.shopRating(s);
    final n = st.shopReviewCount(s);
    final x = st.revOf(s);
    final latest = x != null && x['latest'] is List ? (x['latest'] as List).whereType<Map>().toList() : <Map>[];
    String stars(double v) {
      final f = v.round();
      return List.generate(5, (i) => i < f ? '★' : '☆').join();
    }

    const src = {'app': '✓ சிட்டை ஆர்டர்', 'whatsapp': 'WhatsApp-ல் பெறப்பட்டது', 'phone': 'போனில் பெறப்பட்டது'};
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: P.card, border: Border.all(color: P.bd), borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('⭐ மதிப்பீடுகள்', style: ts(16, w: w8)),
        const SizedBox(height: 10),
        if (r == null && latest.isEmpty)
          Center(
            child: Column(children: [
              const Text('☆', style: TextStyle(fontSize: 26)),
              Text('இன்னும் மதிப்பீடுகள் இல்லை', style: ts(14, w: w8)),
              Text('இந்தக் கடையில் வாங்கிய பிறகு, ஆர்டர்கள் பக்கத்தில் உங்கள் கருத்தைச் சொல்லுங்கள்', textAlign: TextAlign.center, style: ts(12, c: P.mu)),
            ]),
          ),
        if (r != null)
          Row(children: [
            Text(r.toStringAsFixed(1), style: pop(34)),
            Text(' / 5', style: ts(14, w: w7, c: P.mu)),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(stars(r), style: const TextStyle(fontSize: 18, color: Color(0xFFF59E0B))),
              if (n > 0) Text('$n மதிப்பீடுகள்', style: ts(12.5, w: w7, c: P.mu)),
            ]),
          ]),
        if (latest.isEmpty && r != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('எழுத்துக் கருத்துகள் இன்னும் இல்லை', style: ts(12.5, c: P.mu))),
        for (final v in latest)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: P.card2, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(radius: 15, backgroundColor: P.gc, child: Text(js(v['name']).isNotEmpty ? js(v['name']).characters.first : '?', style: ts(13, w: w8, c: P.g2))),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(js(v['name']), style: ts(13.5, w: w8)),
                    if (DateTime.tryParse(js(v['created_at'])) != null)
                      Text(_d(DateTime.parse(js(v['created_at'])).toLocal()), style: ts(11.5, c: P.mu)),
                  ]),
                ),
                if (jz(v['rating']) > 0) Text(stars(jz(v['rating'])), style: const TextStyle(fontSize: 14, color: Color(0xFFF59E0B))),
              ]),
              if (js(v['comment']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(js(v['comment']), style: ts(13.5, h: 1.45))),
              if (src[js(v['source'])] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: P.gc, borderRadius: BorderRadius.circular(8)),
                    child: Text(src[js(v['source'])]!, style: ts(11, w: w8, c: P.g2)),
                  ),
                ),
            ]),
          ),
      ]),
    );
  }

  static String _d(DateTime d) => '${d.day} ${kTaMonthsShort[d.month - 1]} ${d.year}';
}

// ═══ கடைக்குள்: வகை landing → இடது வகைகள் + பொருட்கள் ═══
class ShopScreen extends StatefulWidget {
  final String shopId;
  final String? initialCat, jumpProd;
  const ShopScreen({super.key, required this.shopId, this.initialCat, this.jumpProd});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String _cat = '';
  String? _prodName; // sub-type chip (பச்சரிசி / புழுங்கல் ...)
  bool _landing = false;
  bool _fromLanding = false;
  bool _jumped = false;
  final _grid = ScrollController();
  final _side = ScrollController();

  static const _pal = [0xFFFDF0DD, 0xFFE6F4DC, 0xFFFDE7EA, 0xFFE4EDFB, 0xFFF1E7FB, 0xFFE3F3E6, 0xFFFDE9DF, 0xFFE3EEFC, 0xFFFCE7F1, 0xFFECEBFB];

  @override
  void initState() {
    super.initState();
    final s = AppState.I;
    final cats = s.shopCats(widget.shopId);
    if (widget.initialCat != null && cats.any((c) => c.id == widget.initialCat)) {
      _cat = widget.initialCat!;
      if (widget.jumpProd != null) {
        final p = s.prodByKey(widget.jumpProd!);
        if (p != null) {
          _prodName = p.name;
          _jumped = true;
        }
      }
    } else {
      _cat = cats.isNotEmpty ? cats.first.id : '';
      _landing = cats.length >= 2;
    }
  }

  @override
  void dispose() {
    _grid.dispose();
    _side.dispose();
    super.dispose();
  }

  bool get _innerBack => (_jumped && _prodName != null) || (!_landing && _fromLanding);

  void _back() {
    if (_jumped && _prodName != null) {
      setState(() {
        _prodName = null;
        _jumped = false;
      });
      return;
    }
    if (!_landing && _fromLanding) {
      setState(() {
        _landing = true;
        _fromLanding = false;
      });
    }
  }

  void _goCat(String id, {bool fromLanding = false}) {
    setState(() {
      _cat = id;
      _prodName = null;
      _jumped = false;
      _landing = false;
      if (fromLanding) _fromLanding = true;
    });
    if (_grid.hasClients) _grid.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final sh = s.shopById(widget.shopId);
    final cats = s.shopCats(widget.shopId);
    if (_cat.isNotEmpty && !cats.any((c) => c.id == _cat)) _cat = cats.isNotEmpty ? cats.first.id : '';
    if (_cat.isEmpty && cats.isNotEmpty) _cat = cats.first.id;
    return PopScope(
      canPop: !_innerBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: s.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
        backgroundColor: P.bg,
        body: Column(children: [
          _bar(s, sh),
          Expanded(
            child: Stack(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sidebar(cats),
                Expanded(child: _products(s, sh, cats)),
              ]),
              if (_landing && cats.length >= 2) Positioned.fill(child: _landingView(s, sh, cats)),
              if (s.cartCount > 0) Positioned(left: 12, right: 12, bottom: 10, child: _pill(s)),
            ]),
          ),
        ]),
      ),
      ),
    );
  }

  Widget _bar(AppState s, Shop? sh) {
    final open = sh?.isOpenNow ?? false;
    return Container(
      color: P.card,
      padding: EdgeInsets.fromLTRB(4, MediaQuery.of(context).padding.top + 4, 8, 6),
      child: Row(children: [
        IconButton(icon: Icon(Icons.arrow_back, color: P.text), onPressed: () => Navigator.of(context).maybePop()),
        GestureDetector(
          onTap: () => Nav.openShopDetail(widget.shopId),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: P.gc, borderRadius: BorderRadius.circular(10), border: Border.all(color: P.bd)),
            clipBehavior: Clip.antiAlias,
            child: sh == null
                ? const SizedBox.shrink()
                : (sh.logoImage.isNotEmpty || sh.coverImage.isNotEmpty)
                    ? Img(sh.logoImage.isNotEmpty ? sh.logoImage : sh.coverImage, emoji: '🏪')
                    : Center(child: Text(sh.logoEmoji('🏪'), style: const TextStyle(fontSize: 18))),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => Nav.openShopDetail(widget.shopId),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sh?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(16, w: w8)),
              Row(children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: open ? const Color(0xFF16A34A) : const Color(0xFFDC2626), shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(open ? 'திறந்துள்ளது' : 'மூடப்பட்டுள்ளது', style: ts(12, w: w7, c: P.mu2)),
              ]),
            ]),
          ),
        ),
        IconButton(icon: Icon(Icons.search, color: P.text), onPressed: () => Nav.push(ShopSearchScreen(shopId: widget.shopId))),
        GestureDetector(
          onTap: () => Nav.openShops(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: P.gc, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.storefront_outlined, size: 16, color: P.g2),
              const SizedBox(width: 4),
              Text('கடைகள்', style: ts(12.5, w: w8, c: P.g2)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _sidebar(List<Cat> cats) {
    return Container(
      width: 84,
      decoration: BoxDecoration(color: P.card, border: Border(right: BorderSide(color: P.bd))),
      child: ListView.builder(
        controller: _side,
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: cats.length,
        itemBuilder: (_, i) {
          final c = cats[i];
          final a = c.id == _cat;
          return InkWell(
            onTap: () => _goCat(c.id),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: a ? const Color(0x1400A884) : null,
                border: Border(left: BorderSide(color: a ? P.g : Colors.transparent, width: 3), bottom: BorderSide(color: P.bd)),
              ),
              child: Column(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: P.card2, borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: c.photo.isNotEmpty ? Img(c.photo, emoji: c.e.isNotEmpty ? c.e : '🛍️', emojiSize: 24) : Center(child: Text(c.e, style: const TextStyle(fontSize: 24))),
                ),
                const SizedBox(height: 5),
                Text(c.n, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: ts(11, w: a ? w8 : w7, c: a ? P.g : P.mu2, h: 1.3)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _products(AppState s, Shop? sh, List<Cat> cats) {
    final shopHas = s.prods.any((p) => !p.hidden && p.shopId == widget.shopId);
    if (cats.isEmpty || _cat.isEmpty) {
      if (!shopHas && !s.prodsCached && s.cloudLoading) return const Skeleton(5);
      if (!shopHas && !s.prodsCached && s.cloudFail) return const StateBox('⚠️', 'தகவல்களை ஏற்ற முடியவில்லை', sub: 'தயவுசெய்து மீண்டும் முயற்சி செய்யுங்கள்.', retry: true);
      return StateBox('🛒', shopHas ? 'இந்த வகையில் பொருட்கள் இல்லை' : 'இந்த கடையில் தற்போது பொருட்கள் இல்லை');
    }
    final all = s.catProds(widget.shopId, _cat);
    final cat = cats.where((c) => c.id == _cat).first0;
    final names = <String>[];
    for (final p in all) {
      if (!names.contains(p.name)) names.add(p.name);
    }
    if (_prodName != null && !names.contains(_prodName)) _prodName = null;
    final list = _prodName != null ? all.where((p) => p.name == _prodName).toList() : all;
    int qn(String nm) => all.where((p) => p.name == nm).fold(0, (a, p) => a + s.totalQtyOf(p));
    Widget chip(String? nm, String label) {
      final on = _prodName == nm;
      final n = nm != null ? qn(nm) : 0;
      return GestureDetector(
        onTap: () {
          setState(() {
            _prodName = nm;
            _jumped = false;
          });
          if (_grid.hasClients) _grid.jumpTo(0);
        },
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          constraints: const BoxConstraints(minWidth: 64, maxWidth: 170),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: on ? const Color(0xFFECF8E8) : P.card,
            border: Border.all(color: on ? const Color(0xFF7CB342) : P.bd, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12.5, w: on ? w8 : w7, c: on ? const Color(0xFF2E5D12) : P.text))),
            if (n > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFF7CB342), borderRadius: BorderRadius.circular(9)),
                child: Text('$n', style: ts(11, w: w8, c: Colors.white)),
              ),
            ],
          ]),
        ),
      );
    }

    return CustomScrollView(controller: _grid, slivers: [
      if (sh != null && sh.offerText.isNotEmpty)
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: const Color(0x1AFF8A00), borderRadius: BorderRadius.circular(10)),
            child: Text('🏷️ ${sh.offerText}', style: ts(12, w: w7, c: const Color(0xFFC2650A))),
          ),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 6),
          child: Text.rich(TextSpan(style: ts(14, w: w8), children: [
            TextSpan(text: '${cat?.e ?? ''} ${cat?.n ?? ''}'),
            TextSpan(text: '  ${list.length} பொருட்கள்', style: ts(12, w: w6, c: P.mu)),
          ])),
        ),
      ),
      if (names.length > 1)
        SliverToBoxAdapter(
          child: SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(10, 2, 10, 4), children: [
              chip(null, 'எல்லாம்'),
              for (final nm in names) chip(nm, nm),
            ]),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 110),
        sliver: SliverLayoutBuilder(builder: (ctx, c) {
          final w = (c.crossAxisExtent - 8) / 2;
          final scale = MediaQuery.textScalerOf(ctx).scale(1);
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 8, mainAxisExtent: w + 158 * scale + 8),
            delegate: SliverChildBuilderDelegate((_, i) => ProductCard(list[i]), childCount: list.length),
          );
        }),
      ),
    ]);
  }

  Widget _landingView(AppState s, Shop? sh, List<Cat> cats) {
    return Container(
      color: P.bg,
      child: ListView(padding: const EdgeInsets.fromLTRB(12, 16, 12, 110), children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('எதை வாங்க வேண்டும்?', style: ts(19, w: w8)),
            Text('${sh?.name ?? ''} · ${cats.length} வகைகள்', style: ts(13, w: w7, c: P.mu)),
          ]),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 16, crossAxisSpacing: 10, childAspectRatio: .68),
          itemCount: cats.length,
          itemBuilder: (_, i) {
            final c = cats[i];
            final cut = c.photo.endsWith('#cut');
            final cnt = s.catProds(widget.shopId, c.id).length;
            return GestureDetector(
              onTap: () => _goCat(c.id, fromLanding: true),
              child: Column(children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(color: s.dark ? P.card2 : Color(_pal[i % _pal.length]), borderRadius: BorderRadius.circular(16)),
                    clipBehavior: Clip.antiAlias,
                    child: c.photo.isEmpty
                        ? Center(child: Text(c.e.isNotEmpty ? c.e : '🛍️', style: const TextStyle(fontSize: 34)))
                        : cut
                            ? Padding(padding: const EdgeInsets.all(8), child: Img(c.photo, emoji: c.e.isNotEmpty ? c.e : '🛍️', fit: BoxFit.contain))
                            : Img(c.photo, emoji: c.e.isNotEmpty ? c.e : '🛍️', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 7),
                Text(c.n, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: ts(13, w: w8, h: 1.25)),
                Text('$cnt பொருட்கள்', style: ts(11.5, w: w6, c: P.mu)),
              ]),
            );
          },
        ),
      ]),
    );
  }

  Widget _pill(AppState s) {
    final n = s.cartCount;
    return GestureDetector(
      onTap: () => Nav.openCart(),
      child: Container(
        height: 52,
        padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
        decoration: BoxDecoration(gradient: kBtnGrad, borderRadius: BorderRadius.circular(26), boxShadow: const [BoxShadow(color: Color(0x59008069), blurRadius: 14, offset: Offset(0, 4))]),
        child: Row(children: [
          Container(width: 30, height: 30, decoration: const BoxDecoration(color: Color(0x2EFFFFFF), shape: BoxShape.circle), alignment: Alignment.center, child: const Text('🛒', style: TextStyle(fontSize: 16))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$n ${n == 1 ? 'பொருள்' : 'பொருட்கள்'}', style: ts(13.5, w: w8, c: Colors.white, h: 1.2)),
              Text('· ₹${rupee(s.cartAmount)}', style: ts(12, w: w7, c: Colors.white, h: 1.2)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: const Color(0x2EFFFFFF), borderRadius: BorderRadius.circular(20)),
            child: Text('கூடை பார் ›', style: ts(13.5, w: w8, c: Colors.white)),
          ),
        ]),
      ),
    );
  }
}
