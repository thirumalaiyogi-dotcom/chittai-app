// சிட்டை — "இன்று புதிது" stories (WhatsApp status பாணி) + ஆப் திறக்கும்போது வரும் poster (popup)
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../models.dart';
import '../nav.dart';
import '../state.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';

const Map<String, List<String>> kStKind = {
  'new': ['🥬', 'புதிய வரவு'],
  'offer': ['🏷️', 'இன்றைய சலுகை'],
  'festival': ['🪔', 'பண்டிகை சிறப்பு'],
  'shop': ['🏪', 'புதிய கடை'],
  'notice': ['📢', 'அறிவிப்பு'],
  'recipe': ['🍲', 'இன்றைய சமையல்'],
  'about': ['🙏', 'எங்கள் கடை'],
};

const String kPlayLink = 'https://play.google.com/store/apps/details?id=com.chittai.customer';

List<String> _kind(Map<String, dynamic> s) => kStKind[js(s['kind'])] ?? kStKind['new']!;
String stLabel(Map<String, dynamic> s) => js(s['title']).isNotEmpty ? js(s['title']) : _kind(s)[1];

Set<String> stSeen() {
  final a = Store.json(K.storySeen);
  return a is List ? a.map((x) => js(x)).toSet() : <String>{};
}

void stMarkSeen(String id) {
  final a = stSeen().toList();
  if (!a.contains(id)) {
    a.add(id);
    Store.setJson(K.storySeen, a.length > 300 ? a.sublist(a.length - 300) : a);
  }
}

List<Map<String, dynamic>> stLive() {
  final now = DateTime.now();
  final l = AppState.I.stories.where((s) {
    if (s['hidden'] == true || !js(s['image']).startsWith('https://')) return false;
    final ex = DateTime.tryParse(js(s['expires_at']));
    return s['expires_at'] == null || ex == null || ex.isAfter(now);
  }).toList();
  int ts(Map<String, dynamic> s) => DateTime.tryParse(js(s['created_at']))?.millisecondsSinceEpoch ?? 0;
  l.sort((a, b) {
    final c = jz(a['sort_order']).compareTo(jz(b['sort_order']));
    return c != 0 ? c : ts(b).compareTo(ts(a));
  });
  return l;
}

// ═══ முகப்பில் வட்ட வரிசை ═══
class StoriesRow extends StatelessWidget {
  const StoriesRow({super.key});
  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final live = stLive();
    if (live.isEmpty) return const SizedBox.shrink();
    final seen = stSeen();
    final list = [...live.where((s) => !seen.contains(js(s['id']))), ...live.where((s) => seen.contains(js(s['id'])))];
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 14, bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFE11D48), borderRadius: BorderRadius.circular(10)),
            child: Text('இன்று புதிது', style: ts(12, w: w8, c: Colors.white)),
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final s = list[i];
              final isSeen = seen.contains(js(s['id']));
              return GestureDetector(
                onTap: () => openStories(list, i),
                child: SizedBox(
                  width: 78,
                  child: Column(children: [
                    Container(
                      width: 68,
                      height: 68,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isSeen ? null : const SweepGradient(colors: [Color(0xFF00A884), Color(0xFFF59E0B), Color(0xFFE11D48), Color(0xFF00A884)]),
                        color: isSeen ? const Color(0xFFCBD5D1) : null,
                      ),
                      child: Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: P.card, width: 2.5), color: P.card2),
                        clipBehavior: Clip.antiAlias,
                        child: Img(js(s['image']), emoji: _kind(s)[0], emojiSize: 26),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(stLabel(s), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11.5, w: w7, c: isSeen ? P.mu : P.text)),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

Future<void> openStories(List<Map<String, dynamic>> list, int i) async {
  final c = Nav.ctx;
  if (c == null || list.isEmpty) return;
  await Navigator.of(c).push(PageRouteBuilder(
    opaque: false,
    pageBuilder: (_, __, ___) => StoryViewer(list: list, start: i),
    transitionsBuilder: (_, a, __, ch) => FadeTransition(opacity: a, child: ch),
  ));
  AppState.I.ping();
}

class StoryViewer extends StatefulWidget {
  final List<Map<String, dynamic>> list;
  final int start;
  const StoryViewer({super.key, required this.list, required this.start});
  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late int _i = widget.start.clamp(0, widget.list.length - 1).toInt();
  late final AnimationController _p = AnimationController(vsync: this, duration: const Duration(milliseconds: 5500));
  Offset _down = Offset.zero;
  DateTime _downAt = DateTime.now();
  double _dy = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _p.addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });
    _show();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _p.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.resumed) {
      _p.forward();
    } else {
      _p.stop();
    }
  }

  Map<String, dynamic> get _s => widget.list[_i];

  void _show() {
    stMarkSeen(js(_s['id']));
    _p.forward(from: 0);
    if (_i + 1 < widget.list.length) {
      final u = js(widget.list[_i + 1]['image']);
      if (u.isNotEmpty) precacheImage(NetworkImage(u), context).catchError((_) {});
    }
  }

  void _next() {
    if (_i < widget.list.length - 1) {
      setState(() => _i++);
      _show();
    } else {
      _close();
    }
  }

  void _prev() {
    if (_i > 0) {
      setState(() => _i--);
      _show();
    } else {
      _p.forward(from: 0);
    }
  }

  void _close() {
    if (mounted) Navigator.of(context).maybePop();
  }

  String _ago(String ts) {
    final d = DateTime.tryParse(ts);
    if (d == null) return '';
    final m = DateTime.now().difference(d).inMinutes.clamp(1, 1 << 30).toInt();
    return m < 60 ? '$m நிமிடம் முன்' : (m < 1440 ? '${(m / 60).round()} மணி முன்' : '${(m / 1440).round()} நாள் முன்');
  }

  // CTA: கடை / பொருள் / வகை / சமையல் (எல்லாப் பொருட்களும் கூடையில்) / இணையதளம்
  (String, VoidCallback)? _cta() {
    final s = _s, v = js(s['link_value']), t = js(s['link_type']);
    final st = AppState.I;
    if (t == 'shop') {
      final sh = st.shops.where((x) => x.id == v && !x.hidden).first0;
      return sh == null
          ? null
          : ('கடைக்குச் செல் ›', () {
              _close();
              Nav.openShop(v);
            });
    }
    if (t == 'prod') {
      final p = st.prods.where((x) => x.key == v && !x.hidden).first0;
      return p == null
          ? null
          : ('பொருளைப் பார் ›', () {
              _close();
              Nav.goProd(p);
            });
    }
    if (t == 'kind') {
      return ('பார்க்க ›', () {
        _close();
        Nav.pickType(v);
      });
    }
    if (t == 'recipe') {
      final ps = v.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).map((id) => st.prods.where((p) => p.key == id && !p.hidden && !p.oos && p.packs.isNotEmpty).first0).whereType<Product>().toList();
      return ps.isEmpty ? null : ('🛒 ${ps.length} பொருட்களையும் கூடையில் சேர்', () => _recipe(ps));
    }
    if (t == 'url' && RegExp(r'^https?://').hasMatch(v)) return ('மேலும் அறிய ›', () => openUrl(v));
    return null;
  }

  Future<void> _recipe(List<Product> ps) async {
    _p.stop();
    if (!await CartOps.conflictOk(ps.first)) {
      _p.forward();
      return;
    }
    final st = AppState.I;
    var n = 0;
    for (final p in ps) {
      if (st.qtyOf(p, 0) == 0) {
        st.addLine(p, 0);
        n++;
      }
    }
    _close();
    toast(n > 0 ? '✅ $n பொருட்கள் கூடையில் சேர்ந்தன' : '✅ எல்லாம் ஏற்கனவே கூடையில் உள்ளன');
    Nav.go('cart');
  }

  Future<void> _share() async {
    _p.stop();
    final s = _s;
    final txt = '${js(s['caption']).isNotEmpty ? js(s['caption']) : stLabel(s)} — சிட்டை ஆப்பில் பாருங்கள்: $kPlayLink';
    try {
      await Share.share(txt, subject: 'சிட்டை · இன்று புதிது');
    } catch (_) {
      openUrl('https://wa.me/?text=${Uri.encodeComponent(txt)}');
    }
    if (mounted) _p.forward();
  }

  @override
  Widget build(BuildContext context) {
    final s = _s, k = _kind(s), img = js(s['image']);
    final cta = _cta();
    final mq = MediaQuery.of(context);
    final ago = js(s['created_at']).isNotEmpty ? _ago(js(s['created_at'])) : '';
    return Transform.translate(
      offset: Offset(0, _dy),
      child: Opacity(
        opacity: (1 - _dy / 600).clamp(0.3, 1.0).toDouble(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) {
              _down = d.globalPosition;
              _downAt = DateTime.now();
              _p.stop();
            },
            onPanUpdate: (d) {
              final dy = d.globalPosition.dy - _down.dy;
              if (dy > 0 && dy.abs() > (d.globalPosition.dx - _down.dx).abs()) setState(() => _dy = dy);
            },
            onPanEnd: (d) {
              final dx = d.velocity.pixelsPerSecond.dx;
              if (_dy > 90) {
                _close();
                return;
              }
              setState(() => _dy = 0);
              if (dx.abs() > 300) {
                dx < 0 ? _next() : _prev();
                return;
              }
              _p.forward();
            },
            onPanCancel: () {
              setState(() => _dy = 0);
              final held = DateTime.now().difference(_downAt).inMilliseconds;
              if (held < 250) {
                _down.dx < mq.size.width * .33 ? _prev() : _next();
              } else {
                _p.forward();
              }
            },
            child: Stack(children: [
              // மங்கலான பின்னணி + முழுப் படம்
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Opacity(opacity: .55, child: Img(img, emoji: k[0], fit: BoxFit.cover)),
                ),
              ),
              Positioned.fill(child: Img(img, emoji: k[0], fit: BoxFit.contain, emojiSize: 80)),
              // மேல் progress bars
              Positioned(
                top: mq.padding.top + 8,
                left: 8,
                right: 8,
                child: AnimatedBuilder(
                  animation: _p,
                  builder: (_, __) => Row(children: [
                    for (var j = 0; j < widget.list.length; j++)
                      Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(color: const Color(0x59FFFFFF), borderRadius: BorderRadius.circular(2)),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: j < _i ? 1 : (j == _i ? _p.value : 0),
                            child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
              Positioned(
                top: mq.padding.top + 20,
                left: 12,
                right: 6,
                child: Row(children: [
                  CircleAvatar(radius: 18, backgroundColor: const Color(0x33FFFFFF), child: Text(k[0], style: const TextStyle(fontSize: 18))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(stLabel(s), style: ts(14.5, w: w8, c: Colors.white)),
                      if (ago.isNotEmpty) Text(ago, style: ts(11.5, c: const Color(0xCCFFFFFF))),
                    ]),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: _close),
                ]),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: mq.padding.bottom + 18,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Align(
                    child: GestureDetector(
                      onTap: _share,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(color: const Color(0x40FFFFFF), borderRadius: BorderRadius.circular(22)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.send, size: 17, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('பகிர்', style: ts(14, w: w8, c: Colors.white)),
                        ]),
                      ),
                    ),
                  ),
                  if (js(s['caption']).isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0x8C000000), borderRadius: BorderRadius.circular(14)),
                      child: Text(js(s['caption']), textAlign: TextAlign.center, style: ts(15, w: w7, c: Colors.white, h: 1.45)),
                    ),
                  if (cta != null) ...[
                    const SizedBox(height: 10),
                    GreenButton(cta.$1, onTap: cta.$2),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══ ஆப் திறக்கும்போது poster: ஒரு முறைக்கு ஒன்று, முதல் திறப்பில் இல்லை, ஒருமுறை / தினமும் விதி ═══
class Popups {
  static bool shownThisRun = false;
  static bool firstRun = Store.str(K.firstRun) == null;

  static void markRun() => Store.setStr(K.firstRun, '${DateTime.now().millisecondsSinceEpoch}');

  static Map<String, dynamic>? _pick() {
    final now = DateTime.now();
    final seen = Store.json(K.popupSeen);
    final sm = seen is Map ? seen : const {};
    final l = AppState.I.popups.where((p) {
      if (p['hidden'] == true || !js(p['image']).startsWith('https://')) return false;
      final a = DateTime.tryParse(js(p['starts_at'])), b = DateTime.tryParse(js(p['ends_at']));
      if (a != null && a.isAfter(now)) return false;
      if (b != null && !b.isAfter(now)) return false;
      return true;
    }).toList()
      ..sort((a, b) => jz(a['sort_order']).compareTo(jz(b['sort_order'])));
    for (final p in l) {
      final t = sm[js(p['id'])];
      if (t == null) return p;
      if (js(p['frequency']) == 'once') continue;
      final d = DateTime.fromMillisecondsSinceEpoch(jz(t).toInt());
      if (!(d.year == now.year && d.month == now.month && d.day == now.day)) return p;
    }
    return null;
  }

  static bool _busy() {
    if (Nav.tab.value != 'home' || Nav.depth.value > 0 || Nav.backHandlers.isNotEmpty) return true;
    final r = Nav.root.currentState;
    return r != null && r.canPop();
  }

  static Future<void> maybe([int tries = 0]) async {
    if (shownThisRun || firstRun) return;
    final st = AppState.I;
    if (st.profRaw()['lat'] == null || st.profGet() == null) return; // முதல் முறை வாடிக்கையாளருக்கு விளம்பரம் இல்லை
    final p = _pick();
    if (p == null) return;
    if (_busy()) {
      if (tries < 15) Future.delayed(const Duration(seconds: 2), () => maybe(tries + 1));
      return;
    }
    final c = Nav.ctx;
    if (c == null) return;
    try {
      await precacheImage(NetworkImage(js(p['image'])), c);
    } catch (_) {
      return;
    }
    if (shownThisRun || _busy()) return;
    shownThisRun = true;
    final seen = Store.json(K.popupSeen);
    final sm = seen is Map ? Map<String, dynamic>.from(seen) : <String, dynamic>{};
    sm[js(p['id'])] = DateTime.now().millisecondsSinceEpoch;
    Store.setJson(K.popupSeen, sm);
    final has = js(p['link_type']).isNotEmpty && js(p['link_type']) != 'none';
    final go = await showDialog<bool>(
      context: Nav.ctx!,
      barrierColor: const Color(0xB3000000),
      builder: (d) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(22),
        child: Stack(clipBehavior: Clip.none, children: [
          Column(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: () => Navigator.pop(d, has),
              child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Img(js(p['image']), fit: BoxFit.contain)),
            ),
            if (has) ...[
              const SizedBox(height: 12),
              SizedBox(width: 180, child: GreenButton('பார்க்க ›', height: 46, onTap: () => Navigator.pop(d, true))),
            ],
          ]),
          Positioned(
            top: -12,
            right: -12,
            child: GestureDetector(
              onTap: () => Navigator.pop(d, false),
              child: const CircleAvatar(radius: 18, backgroundColor: Colors.white, child: Icon(Icons.close, color: Colors.black87, size: 20)),
            ),
          ),
        ]),
      ),
    );
    if (go == true) linkGo(js(p['link_type']), js(p['link_value']));
  }
}

// banners + popups: சரிபார்த்த இடங்கள் மட்டும்
void linkGo(String t, String v) {
  final s = AppState.I;
  if (t == 'shop' && s.shops.any((x) => x.id == v && !x.hidden)) {
    Nav.openShop(v);
  } else if (t == 'kind' && s.kinds.any((k) => k.id == v)) {
    Nav.pickType(v);
  } else if (t == 'url' && RegExp(r'^https?://', caseSensitive: false).hasMatch(v)) {
    openUrl(v);
  }
}

String get appShareText => '🛒 சிட்டை — அருகிலுள்ள கடைகளில் எளிதாக ஆர்டர் செய்ய: $kPlayLink';
String get appVersionText => 'சிட்டை · பதிப்பு $kAppVersion';

// ஏற்றும் முன் popups தரவு வந்ததா என்று காத்திருந்து
Future<void> schedulePopup() async {
  for (var i = 0; i < 20 && AppState.I.cloudLoading; i++) {
    await Future.delayed(const Duration(milliseconds: 500));
  }
  await Future.delayed(const Duration(seconds: 2));
  unawaited(Popups.maybe());
}
