// சிட்டை — முகப்பு: header, இடம், தேடல், அறிவிப்பு, banners, கடை வகைகள், அருகிலுள்ள கடைகள், மீண்டும் வாங்க, சலுகைகள், பெரியவர் card
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../nav.dart';
import '../orders.dart';
import '../search_engine.dart';
import '../state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'account.dart';
import 'location.dart';
import 'notifs.dart';
import 'orders.dart';
import 'search.dart';
import 'stories.dart';

// ═══ பச்சை header: "சிட்டை." + 🔔 ❤️ 👤 ═══
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});
  @override
  Widget build(BuildContext context) {
    final favN = context.select<AppState, int>((s) => s.favIds.length);
    context.watch<AppState>();
    var unread = 0;
    try {
      unread = Nt.unread();
    } catch (_) {}
    Widget btn(Widget ic, VoidCallback f, {bool dot = false}) => InkResponse(
          onTap: f,
          radius: 22,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
              ic,
              if (dot)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(width: 9, height: 9, decoration: BoxDecoration(color: const Color(0xFFFFC107), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5))),
                ),
            ]),
          ),
        );
    return Container(
      decoration: BoxDecoration(gradient: kHeroGrad),
      padding: EdgeInsets.fromLTRB(14, MediaQuery.of(context).padding.top + 8, 6, 2),
      child: Row(children: [
        RichText(
          text: TextSpan(style: pop(23, c: Colors.white), children: const [
            TextSpan(text: 'சிட்டை'),
            TextSpan(text: '.', style: TextStyle(color: Color(0xD9FFFFFF))),
          ]),
        ),
        const Spacer(),
        ListenableBuilder(
          listenable: Orders.I,
          builder: (_, __) {
            var n = unread;
            try {
              n = Nt.unread();
            } catch (_) {}
            // HTML .bell-dot (வரி 1674 + 2245): பொத்தானின் மேல்-வலது top 3 right 2
            return InkResponse(
              onTap: () => pushFull(const NotifScreen()),
              radius: 22,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                  const Icon(Icons.notifications, color: Colors.white, size: 25),
                  if (n > 0)
                    Positioned(
                      top: 3,
                      right: 2,
                      child: Container(
                        height: 18,
                        constraints: const BoxConstraints(minWidth: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(9), border: Border.all(color: P.hdr, width: 2)),
                        child: Text(n > 9 ? '9+' : '$n', textAlign: TextAlign.center, style: pop(12, c: Colors.white).copyWith(height: 1)),
                      ),
                    ),
                ]),
              ),
            );
          },
        ),
        btn(Icon(favN > 0 ? Icons.favorite : Icons.favorite_border, color: Colors.white, size: 24), () => pushFull(const FavScreen())),
        btn(const Icon(Icons.account_circle, color: Colors.white, size: 26), () => pushFull(const AccountScreen())),
      ]),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _q = TextEditingController();
  final _f = FocusNode();
  final _scroll = ScrollController();
  bool _srActive = false, _committed = false;
  String _query = '';
  Timer? _deb;
  final SrCtl _ctl = SrCtl();
  bool _kAll = false;
  final SpeechToText _stt = SpeechToText();
  bool _mic = false, _sttReady = false;

  // 🎤 தமிழ் குரல் தேடல் (phone-ன் Google speech)
  Future<void> _voice() async {
    if (_mic) {
      await _stt.stop();
      if (mounted) setState(() => _mic = false);
      return;
    }
    try {
      if (!_sttReady) {
        _sttReady = await _stt.initialize(
          onError: (_) {
            if (mounted) setState(() => _mic = false);
            toast('🎤 கேட்க முடியவில்லை — மீண்டும் முயற்சிக்கவும்');
          },
          onStatus: (st) {
            if ((st == 'done' || st == 'notListening') && mounted) setState(() => _mic = false);
          },
        );
      }
      if (!_sttReady) {
        toast('இந்த phone-ல் குரல் தேடல் இல்லை');
        return;
      }
      setState(() => _mic = true);
      toast('🎤 பேசுங்கள்...');
      await _stt.listen(
        localeId: 'ta_IN',
        onResult: (r) {
          if (!r.finalResult) return;
          final t = r.recognizedWords.trim();
          if (t.isEmpty) return;
          _q.text = t;
          _onType(t);
          _commit(t);
        },
      );
    } catch (_) {
      if (mounted) setState(() => _mic = false);
      toast('இந்த phone-ல் குரல் தேடல் இல்லை');
    }
  }
  bool _fabTuck = false;
  double _lastY = 0;

  @override
  void initState() {
    super.initState();
    TypingHint.attach();
    Nav.homeReset.addListener(_reset);
    schedulePopup();
    _f.addListener(() {
      if (_f.hasFocus) _enter();
      setState(() {});
    });
    _scroll.addListener(() {
      final y = _scroll.offset;
      final tuck = y > _lastY + 6 && y > 120;
      if (tuck != _fabTuck && (tuck || y < _lastY - 6 || y < 120)) setState(() => _fabTuck = tuck);
      _lastY = y;
    });
  }

  @override
  void dispose() {
    TypingHint.detach();
    Nav.homeReset.removeListener(_reset);
    Nav.backHandlers.remove(_exit);
    _deb?.cancel();
    _q.dispose();
    _f.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _reset() {
    if (_srActive) _exit();
    if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _enter() {
    if (_srActive) return;
    setState(() => _srActive = true);
    Nav.backHandlers.add(_exit);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _exit() {
    Nav.backHandlers.remove(_exit);
    _deb?.cancel();
    _q.clear();
    _f.unfocus();
    setState(() {
      _srActive = false;
      _committed = false;
      _query = '';
      _ctl.reset();
    });
  }

  void _onType(String v) {
    _committed = false;
    _ctl.reset();
    _deb?.cancel();
    if (v.trim().isEmpty) {
      setState(() => _query = v);
    } else {
      _deb = Timer(const Duration(milliseconds: 180), () => setState(() => _query = v));
    }
  }

  void _commit(String v) {
    if (v.trim().isEmpty) return;
    _q.text = v;
    _q.selection = TextSelection.collapsed(offset: v.length);
    if (!_srActive) _enter();
    SrHist.add(v.trim());
    _f.unfocus();
    setState(() {
      _query = v;
      _committed = true;
      _ctl.limit = 20;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final searching = _srActive || _query.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: P.bg,
      body: Stack(children: [
        Column(children: [
          const AppHeader(),
          Expanded(
            child: RefreshIndicator(
              color: P.g,
              onRefresh: () => s.runCloudLoad(),
              notificationPredicate: (n) => !searching && n.depth == 0,
              child: CustomScrollView(controller: _scroll, slivers: [
                SliverToBoxAdapter(child: _hero(s)),
                if (!searching) ..._discover(s) else SliverToBoxAdapter(child: _searchBody()),
              ]),
            ),
          ),
        ]),
        if (!searching) _fab(),
      ]),
    );
  }

  Widget _searchBody() {
    final q = _query.trim();
    if (!s0Ready) return const Skeleton(4);
    if (q.isEmpty) return SearchHomeView(onCommit: _commit);
    if (!_committed) {
      return SuggestView(
        q: q,
        onCommit: _commit,
        onFill: (t) {
          _q.text = t;
          _q.selection = TextSelection.collapsed(offset: t.length);
          _onType(t);
        },
      );
    }
    return ResultsView(q: q, ctl: _ctl, onCommit: _commit);
  }

  bool get s0Ready => !(AppState.I.cloudLoading && !AppState.I.shopsCached);

  // ── பச்சைப் பகுதி: இடம் + தேடல் பெட்டி ──
  Widget _hero(AppState s) {
    final pf = s.profRaw();
    final pr = s.profGet();
    var area = js(pf['area']);
    if (area.isEmpty && pr != null) {
      final parts = js(pr['ad']).split(RegExp(r'[,\n]')).map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
      area = parts.length > 2 ? parts.sublist(parts.length - 2).join(', ') : parts.join(', ');
    }
    final locTxt = area.isNotEmpty ? area : (s.locState == 'ok' ? 'உங்கள் இடம் கண்டறியப்பட்டது' : 'டெலிவரி முகவரியைச் சேர்க்கவும்');
    return Container(
      decoration: BoxDecoration(gradient: kHeroGrad, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!_srActive)
          GestureDetector(
            onTap: () => showLocationSheet(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_on, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Flexible(child: Text(locTxt, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(15, w: w8, c: Colors.white))),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
              ]),
            ),
          ),
        Container(
          height: 54,
          margin: const EdgeInsets.only(top: 10),
          padding: EdgeInsets.only(left: _srActive ? 2 : 14, right: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _f.hasFocus ? const Color(0xFF00A884) : const Color(0xFFE3EAE7)),
            boxShadow: const [BoxShadow(color: Color(0x12143C32), blurRadius: 14, offset: Offset(0, 4))],
          ),
          child: Row(children: [
            if (_srActive)
              IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF00A884)), onPressed: _exit)
            else
              const Icon(Icons.search, color: Color(0xFF00A884), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: TypingHint.prod,
                builder: (_, hint, __) => TextField(
                  controller: _q,
                  focusNode: _f,
                  onChanged: _onType,
                  onSubmitted: _commit,
                  textInputAction: TextInputAction.search,
                  style: ts(16, w: w6, c: const Color(0xFF17201D)),
                  cursorColor: const Color(0xFF00A884),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: _f.hasFocus || _srActive ? 'பொருள், கடை அல்லது வகையைத் தேடுங்கள்...' : hint,
                    hintStyle: ts(15, w: w6, c: const Color(0xFF6B7773)),
                  ),
                ),
              ),
            ),
            // HTML .hm-x: 38px வட்டம் #eef2f1; எழுத்து இருக்கும்போது mic மறையும் (.hm-x.on~.hm-mic)
            if (_q.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _q.clear();
                  _onType('');
                  _f.requestFocus();
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(color: Color(0xFFEEF2F1), shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Color(0xFF5D6B68), size: 20),
                ),
              )
            else
              GestureDetector(
                onTap: _voice,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: _mic ? const Color(0xFFFFE3E3) : Colors.transparent, shape: BoxShape.circle),
                  child: Icon(Icons.mic_none, color: _mic ? const Color(0xFFD93025) : (s.dark ? P.g2 : const Color(0xFF00A884))),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  // ── கண்டுபிடி பகுதி ──
  List<Widget> _discover(AppState s) {
    final out = <Widget>[];
    if (s.notice.isNotEmpty) out.add(SliverToBoxAdapter(child: NoticeBar(s.notice, key: ValueKey(s.notice))));
    out.add(const SliverToBoxAdapter(child: BannerCarousel()));
    out.add(const SliverToBoxAdapter(child: ActiveOrderStrip()));
    out.add(const SliverToBoxAdapter(child: StoriesRow()));
    final allKinds = s.kinds.where((k) => !k.hide).toList();
    if (allKinds.isNotEmpty) {
      final more = allKinds.length > 8 && !_kAll;
      final show = more ? allKinds.take(7).toList() : allKinds;
      out.add(SliverToBoxAdapter(child: SecHead('எதை வாங்கப் போகிறீர்கள்?', more: 'கடைகள்', onMore: () => Nav.go('shops'))));
      out.add(SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        sliver: SliverGrid.count(
          crossAxisCount: 4,
          mainAxisSpacing: 14,
          crossAxisSpacing: 8,
          childAspectRatio: .66,
          children: [
            for (final k in show)
              GestureDetector(
                onTap: () => Nav.pickType(k.id),
                child: Column(children: [
                  LayoutBuilder(builder: (_, c) => KindCircle(k, size: c.maxWidth.clamp(40.0, 72.0).toDouble())),
                  const SizedBox(height: 6),
                  Text(k.n, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: ts(12.5, w: w8, h: 1.25)),
                ]),
              ),
            if (more)
              GestureDetector(
                onTap: () => setState(() => _kAll = true),
                child: Column(children: [
                  LayoutBuilder(
                    builder: (_, c) {
                      final z = c.maxWidth.clamp(40.0, 72.0).toDouble();
                      return Container(
                        width: z,
                        height: z,
                        decoration: BoxDecoration(color: P.gc, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text('+${allKinds.length - 7}', style: ts(18, w: w8, c: P.g2)),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text('மேலும்', style: ts(12.5, w: w8)),
                ]),
              ),
          ],
        ),
      ));
    }
    out.add(SliverToBoxAdapter(child: _nearShops(s)));
    out.add(SliverToBoxAdapter(child: _again(s)));
    out.add(SliverToBoxAdapter(child: KeyedSubtree(key: Nav.dealsKey, child: _deals(s))));
    out.add(SliverToBoxAdapter(child: _elder(s)));
    // HTML: வகைகள் இருக்கும்போது home-list மறைந்திருக்கும் (ஏற்றுதல் / பிழைப் பெட்டிகள் ShopList-க்குள்)
    if (allKinds.isEmpty) out.add(const SliverToBoxAdapter(child: ShopList(type: '')));
    out.add(const SliverToBoxAdapter(child: SizedBox(height: 90)));
    return out;
  }

  Widget _row(List<Widget> kids, double h) => Builder(
        builder: (c) => SizedBox(
          height: h * MediaQuery.textScalerOf(c).scale(1).clamp(1.0, 1.4).toDouble(),
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), children: kids),
        ),
      );

  // அருகிலுள்ள கடைகள்: திறந்தவை முதலில், பிறகு தூரம்
  Widget _nearShops(AppState s) {
    final l = s.visibleShops.toList()
      ..sort((a, b) {
        final c = (b.isOpenNow ? 1 : 0) - (a.isOpenNow ? 1 : 0);
        if (c != 0) return c;
        return (s.shopKm(a) ?? 1e9).compareTo(s.shopKm(b) ?? 1e9);
      });
    final list = l.take(10).toList();
    if (list.length < 2) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SecHead('அருகிலுள்ள கடைகள்', icon: Icons.storefront_outlined, more: 'அனைத்தும்', onMore: () => Nav.go('shops')),
      _row(list.map((sh) {
        final t = s.kindOf(sh);
        final img = sh.coverImage.isNotEmpty ? sh.coverImage : (sh.logoImage.isNotEmpty ? sh.logoImage : (t != null ? (s.kindImg[t.id] ?? '') : ''));
        final o = sh.isOpenNow, d = s.shopDistText(sh);
        return GestureDetector(
          onTap: () => Nav.openShop(sh.id),
          child: Container(
            width: 132,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.fromLTRB(7, 7, 7, 9),
            decoration: BoxDecoration(color: P.card, border: Border.all(color: P.bd), borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x0D143C32), blurRadius: 8, offset: Offset(0, 2))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                height: 82,
                width: double.infinity,
                decoration: BoxDecoration(color: t != null ? hexColor(s.kindBg(t)) : P.gc, borderRadius: BorderRadius.circular(11)),
                clipBehavior: Clip.antiAlias,
                child: img.isNotEmpty ? Img(img, emoji: t?.e ?? '🏪', fit: img.endsWith('#cut') ? BoxFit.contain : BoxFit.cover) : Center(child: Text(t?.e ?? '🏪', style: const TextStyle(fontSize: 36))),
              ),
              const SizedBox(height: 6),
              Text(sh.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, w: w8)),
              Row(children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: o ? const Color(0xFF16A34A) : const Color(0xFFDC2626), shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Expanded(child: Text('${o ? 'திறந்துள்ளது' : 'மூடியுள்ளது'}${d.isNotEmpty ? ' · $d' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, w: w7, c: P.mu))),
              ]),
            ]),
          ),
        );
      }).toList(), 152),
    ]);
  }

  // மீண்டும் வாங்க: இந்த phone-ல் முன்பு ஆர்டர் செய்தவை
  Widget _again(AppState s) {
    final seen = <String>{};
    final out = <MapEntry<Product, int>>[];
    for (final o in s.ordLocal()) {
      final its = o['its'];
      if (its is! List) continue;
      for (final i in its) {
        if (out.length >= 10 || i is! Map || i['pid'] == null) continue;
        final pid = js(i['pid']);
        if (seen.contains(pid)) continue;
        final p = s.prods.where((x) => x.key == pid && !x.hidden).first0;
        if (p == null || p.packs.isEmpty) continue;
        final sh = s.shopById(p.shopId);
        if (sh == null || sh.hidden) continue;
        var pi = p.packs.indexWhere((k) => k.w == js(i['w']));
        if (pi < 0) pi = 0;
        seen.add(pid);
        out.add(MapEntry(p, pi));
      }
    }
    if (out.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SecHead('மீண்டும் வாங்க', icon: Icons.repeat, more: 'ஆர்டர்கள்', onMore: () => Nav.go('orders')),
      _row(out.map((e) => HxCard(e.key, e.value)).toList(), 236),
    ]);
  }

  // இன்றைய சலுகைகள்: MRP > விலை, அதிக சேமிப்பு முதலில்
  Widget _deals(AppState s) {
    final out = <List<dynamic>>[];
    for (final p in s.prods) {
      if (p.hidden || p.packs.isEmpty) continue;
      final sh = s.shopById(p.shopId);
      if (sh == null || sh.hidden) continue;
      var best = -1;
      double bd = 0;
      for (var i = 0; i < p.packs.length; i++) {
        final o = p.packs[i].offer;
        if (o != null && (best < 0 || o.mrp - p.packs[i].price > bd)) {
          best = i;
          bd = o.mrp - p.packs[i].price;
        }
      }
      if (best >= 0) out.add([p, best, bd]);
    }
    if (out.isEmpty) return const SizedBox.shrink();
    out.sort((a, b) => (b[2] as double).compareTo(a[2] as double));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SecHead('இன்றைய சலுகைகள்', icon: Icons.local_offer_outlined),
      _row(out.take(12).map((x) => HxCard(x[0] as Product, x[1] as int, badge: '₹${rupee(x[2])} குறைவு')).toList(), 236),
    ]);
  }

  // 👴 பெரியவர்களுக்கு: சீட்டை WhatsApp-ல் அனுப்பு / அழை
  Widget _elder(AppState s) {
    final n = supNum(s.waNum);
    if (n.isEmpty) return const SizedBox.shrink();
    final p = s.profRaw();
    final txt = 'வணக்கம் 🙏 இந்தப் பொருட்கள் வேண்டும் — சீட்டின் போட்டோவை இத்துடன் அனுப்புகிறேன்.'
        '${js(p['nm']).isNotEmpty ? '\nபெயர்: ${js(p['nm'])}' : ''}${js(p['ad']).isNotEmpty ? '\nமுகவரி: ${js(p['ad'])}' : ''}';
    // HTML .eld (வரி 1810-1816) — இரு theme-லும் அதே நிறங்கள்
    Widget btn(String t, Color bg, Color fg, VoidCallback f, {Border? border}) => Expanded(
          child: GestureDetector(
            onTap: f,
            child: Container(
              constraints: const BoxConstraints(minHeight: 46),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: border),
              child: Text(t, textAlign: TextAlign.center, style: ts(14, w: w8, c: fg)),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFF8EC), Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: const Color(0xFFF6DFB5)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFFFECC7), borderRadius: BorderRadius.circular(14)),
            child: const Text('🙏', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('App-ல் போடத் தெரியவில்லையா?', style: ts(15, w: w8, c: const Color(0xFF5C3B00))),
              const SizedBox(height: 2),
              Text('சீட்டை எழுதி போட்டோ எடுத்து அனுப்புங்கள், அல்லது அழையுங்கள் — நாங்களே ஆர்டர் போட்டு வீட்டுக்கு அனுப்புகிறோம்',
                  style: ts(12.5, c: const Color(0xFF7A5A1E), h: 1.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          btn('📷 சீட்டை WhatsApp-ல் அனுப்பு', const Color(0xFF25D366), Colors.white, () => openUrl('https://wa.me/$n?text=${Uri.encodeComponent(txt)}')),
          const SizedBox(width: 8),
          btn('📞 அழைத்து சொல்லு', Colors.white, const Color(0xFF5C3B00), () => openUrl('tel:+$n'), border: Border.all(color: const Color(0xFFF0CF8F), width: 1.5)),
        ]),
      ]),
    );
  }

  // WhatsApp உதவி பொத்தான் (முகப்பில் மட்டும்; கீழே scroll செய்தால் ஒளிந்துகொள்ளும்)
  Widget _fab() {
    return Positioned(
      right: 14,
      bottom: 16,
      child: AnimatedSlide(
        offset: _fabTuck ? const Offset(0, 2) : Offset.zero,
        duration: const Duration(milliseconds: 250),
        child: const _WaFab(),
      ),
    );
  }
}

class _WaFab extends StatefulWidget {
  const _WaFab();
  @override
  State<_WaFab> createState() => _WaFabState();
}

class _WaFabState extends State<_WaFab> {
  static bool _shownOnce = false;
  bool _label = !_shownOnce;
  @override
  void initState() {
    super.initState();
    _shownOnce = true;
    if (_label) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _label = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => waHelp(),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        AnimatedOpacity(
          opacity: _label ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: P.card, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 10, offset: Offset(0, 3))]),
            child: Text('உதவி வேண்டுமா?', style: ts(13, w: w8)),
          ),
        ),
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x5525D366), blurRadius: 14, offset: Offset(0, 5))]),
          child: const Icon(Icons.chat, color: Colors.white, size: 28),
        ),
      ]),
    );
  }
}

// ═══ Banners: 4 வினாடிக்கு ஒருமுறை தானாக நகரும் ═══
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key});
  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _pc = PageController();
  Timer? _t;
  int _i = 0;
  DateTime _hold = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 4), (_) {
      final n = _list().length;
      if (n < 2 || !_pc.hasClients || DateTime.now().isBefore(_hold)) return;
      if (Nav.tab.value != 'home' || Nav.depth.value > 0) return;
      _pc.animateToPage((_i + 1) % n, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _pc.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _list() {
    final l = AppState.I.banners.where((b) => b['hidden'] != true && js(b['image']).startsWith('https://')).toList();
    l.sort((a, b) => jz(a['sort_order']).compareTo(jz(b['sort_order'])));
    return l;
  }

  void _tap(Map<String, dynamic> b) {
    final v = js(b['link_value']);
    final t = js(b['link_type']);
    final s = AppState.I;
    if (t == 'shop' && s.shops.any((x) => x.id == v && !x.hidden)) {
      Nav.openShop(v);
    } else if (t == 'kind' && s.kinds.any((k) => k.id == v)) {
      Nav.pickType(v);
    } else if (t == 'url' && RegExp(r'^https?://', caseSensitive: false).hasMatch(v)) {
      openUrl(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final l = _list();
    if (l.isEmpty) return const SizedBox.shrink();
    if (_i >= l.length) _i = 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 12 / 5,
            child: Listener(
              onPointerDown: (_) => _hold = DateTime.now().add(const Duration(seconds: 6)),
              child: PageView.builder(
                controller: _pc,
                itemCount: l.length,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _tap(l[i]),
                  child: Container(color: P.card2, child: Img(js(l[i]['image']), emoji: '🛍️')),
                ),
              ),
            ),
          ),
        ),
        if (l.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < l.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _i ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(color: i == _i ? P.g : P.bd, borderRadius: BorderRadius.circular(3)),
                ),
            ]),
          ),
      ]),
    );
  }
}

// ═══ கடைப் பட்டியல் (பெரிய படம் card-கள்) — கடைகள் tab-லும் பயன்படும் ═══
class ShopList extends StatefulWidget {
  final String type; // '' = எல்லாம்
  final String query;
  const ShopList({super.key, required this.type, this.query = ''});
  @override
  State<ShopList> createState() => _ShopListState();
}

class _ShopListState extends State<ShopList> {
  String _sort = '';

  void _rst() {
    if (mounted && _sort.isNotEmpty) setState(() => _sort = '');
  }

  @override
  void initState() {
    super.initState();
    Nav.shopsReset.addListener(_rst);
  }

  @override
  void dispose() {
    Nav.shopsReset.removeListener(_rst);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (s.cloudLoading && !s.shopsCached) return const Skeleton(4);
    if (s.cloudFail && !s.shopsCached && s.visibleShops.isEmpty) {
      return const StateBox('⚠️', 'தகவல்களை ஏற்ற முடியவில்லை', sub: 'தயவுசெய்து மீண்டும் முயற்சி செய்யுங்கள்.', retry: true);
    }
    if (s.visibleShops.isEmpty) return const StateBox('🏪', 'அருகில் கடைகள் கிடைக்கவில்லை');
    final q = widget.query.trim();
    final all = s.visibleShops.where((x) => widget.type.isEmpty || q.isNotEmpty || s.shopType(x) == widget.type).toList();
    final anyKm = all.any((x) => s.shopKm(x) != null);
    final anyRating = all.any((x) => jz(x.m['rating']) > 0);
    final eff = _sort.isNotEmpty ? _sort : (anyKm ? 'near' : 'all');
    List<Shop> list;
    if (q.isNotEmpty) {
      final ids = SearchEngine.searchShops(q).map((x) => x.id).toList();
      list = all.where((x) => ids.contains(x.id)).toList()..sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
    } else {
      list = List.of(all);
    }
    if (eff == 'near' && anyKm) {
      list.sort((a, b) {
        final x = s.shopKm(a), y = s.shopKm(b);
        if (x != null && y != null) return x.compareTo(y);
        if (x != null) return -1;
        if (y != null) return 1;
        return a.sortOrder.compareTo(b.sortOrder);
      });
    } else if (eff == 'rating' && anyRating) {
      list.sort((a, b) => jz(b.m['rating']).compareTo(jz(a.m['rating'])));
    }
    final kt = s.kindById(widget.type);
    final title = q.isNotEmpty ? 'கடைகள்' : (widget.type.isNotEmpty ? 'அருகிலுள்ள ${kt?.n ?? ''} கடைகள்' : 'உங்களுக்கு அருகிலுள்ள கடைகள்');
    Widget chip(String k, String l) => GestureDetector(
          onTap: () => setState(() => _sort = k),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: eff == k ? P.g : P.card,
              border: Border.all(color: eff == k ? P.g : P.bd, width: 1.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(l, style: ts(12, w: w7, c: eff == k ? Colors.white : P.mu2)),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(14, 16, 14, 10), child: Text('$title (${list.length})', style: ts(14.5, w: w8))),
      if (anyKm || anyRating)
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), children: [
            chip('all', 'எல்லாம்'),
            if (anyKm) chip('near', '📍 அருகில்'),
            if (anyRating) chip('rating', '⭐ அதிக மதிப்பீடு'),
          ]),
        ),
      if (list.isEmpty)
        widget.type.isNotEmpty && q.isEmpty
            ? const StateBox('🕒', 'இந்த வகையில் கடைகள் விரைவில் வரும்', sub: 'மற்ற வகைகளைப் பாருங்கள்')
            : const StateBox('🔍', 'கடை கிடைக்கவில்லை')
      else
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Column(children: list.map((x) => ShopCard(x)).toList()),
        ),
    ]);
  }
}

// homeCardHTML: மேலே பெரிய படம், கீழே விவரம்
class ShopCard extends StatelessWidget {
  final Shop s;
  const ShopCard(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final st = AppState.I;
    final open = s.isOpenNow, d = st.shopDistText(s), r = st.shopRating(s);
    final kt = st.kindOf(s);
    final bg = kt != null ? hexColor(st.kindBg(kt)) : P.gc;
    final kimg = kt != null ? (st.kindImg[kt.id] ?? '') : '';
    Widget pic;
    if (s.coverImage.isNotEmpty) {
      pic = Img(s.coverImage, emoji: kt?.e ?? '🏪', fit: BoxFit.cover, emojiSize: 56);
    } else if (s.logoImage.isNotEmpty) {
      // HTML .sc-logo: 108×108 வெள்ளைப் பெட்டி, radius 24, நிழல்
      pic = Center(
        child: Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x24000000), blurRadius: 20, offset: Offset(0, 8))]),
          clipBehavior: Clip.antiAlias,
          child: Img(s.logoImage, emoji: kt?.e ?? '🏪', fit: BoxFit.cover, emojiSize: 56),
        ),
      );
    } else if (kimg.isNotEmpty) {
      pic = kimg.endsWith('#cut')
          ? Center(child: SizedBox(width: 120, height: 120, child: Img(kimg, emoji: kt?.e ?? '🏪', fit: BoxFit.contain, emojiSize: 56)))
          : Img(kimg, emoji: kt?.e ?? '🏪', fit: BoxFit.cover, emojiSize: 56);
    } else {
      pic = Center(child: Text(s.logoEmoji(kt?.e ?? '🏪'), style: const TextStyle(fontSize: 64)));
    }
    final sub = [if (s.description.isNotEmpty) s.description, if (d.isNotEmpty) '$d தூரம்'].join(' · ');
    Widget del;
    if (!open) {
      del = Text('🔴 இப்போது மூடப்பட்டுள்ளது', style: ts(14, w: w8, c: P.mu2));
    } else if (!s.deliveryAvailable) {
      del = Text('🚫 டெலிவரி இல்லை', style: ts(14, w: w8, c: P.mu2));
    } else if (s.etaKnown) {
      del = Row(children: [
        Icon(Icons.schedule, size: 16, color: P.g2),
        const SizedBox(width: 5),
        Flexible(child: Text('${s.etaText} நிமிடத்தில் டெலிவரி', style: ts(14, w: w8, c: P.g2))),
      ]);
    } else {
      del = Text('🟢 திறந்துள்ளது', style: ts(14, w: w8, c: P.g2));
    }
    final active = s.id == st.activeShop;
    return GestureDetector(
      onTap: () => Nav.openShop(s.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: P.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: active ? P.g : P.bd, width: active ? 1.5 : 1),
          // light: HTML 2204 வரி (0 2px 8px .05); dark: .sc2 (0 6px 18px .08)
          boxShadow: st.dark ? const [BoxShadow(color: Color(0x14143C32), blurRadius: 18, offset: Offset(0, 6))] : const [BoxShadow(color: Color(0x0D143C32), blurRadius: 8, offset: Offset(0, 2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 168,
            child: Stack(fit: StackFit.expand, children: [
              Container(color: bg),
              pic,
              if (kt != null)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xF0FFFFFF), borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))]),
                    child: Text(kt.n, style: ts(12, w: w8, c: const Color(0xFF1B2725))),
                  ),
                ),
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () => Nav.openShopDetail(s.id),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: Color(0xF0FFFFFF), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2))]),
                    child: const Icon(Icons.info_outline, size: 20, color: Color(0xFF3B4A47)),
                  ),
                ),
              ),
              if (!open)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 26, 14, 10),
                    decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xB8000000)])),
                    child: Text(
                      '🔴 இப்போது மூடப்பட்டுள்ளது${s.isOpenFlag && s.openingTime.isNotEmpty ? ' · ${tTime(s.openingTime)}-க்கு திறக்கும்' : ''}',
                      style: ts(13, w: w8, c: Colors.white),
                    ),
                  ),
                )
              else if (s.offerText.isNotEmpty)
                Positioned(
                  left: 12,
                  bottom: 12,
                  right: 12,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFFE8590C), borderRadius: BorderRadius.circular(10)),
                      child: Text('🏷️ ${s.offerText}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, w: w8, c: Colors.white)),
                    ),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(17.5, w: w8))),
                if (r != null) ...[
                  const SizedBox(width: 10),
                  Text('★ ${r.toStringAsFixed(1)}', style: ts(15, w: w8, c: const Color(0xFFE08A00))), // HTML .sc-rt
                ],
              ]),
              if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13.5, w: w6, c: P.mu2))),
              const SizedBox(height: 10),
              del,
            ]),
          ),
        ]),
      ),
    );
  }
}
