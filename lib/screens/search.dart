// சிட்டை — தேடல் திரைகள்: தேடல் முகப்பு, பரிந்துரைகள், முடிவுகள் (வடிகட்டு / வரிசை), கடைக்குள் தேடல்
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../nav.dart';
import '../search_engine.dart';
import '../state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';

// ═══ ⌨️ தேடல் பெட்டியில் தானாக "டைப்" ஆகும் எழுத்துகள் ═══
class TypingHint {
  static const _base = ['அரிசி', 'பால்', 'பருப்பு', 'எண்ணெய்', 'சர்க்கரை', 'காய்கறி', 'முட்டை', 'கேக்', 'பிஸ்கட்', 'சோப்பு'];
  static const pre = 'தேடுங்கள்: "';
  static final ValueNotifier<String> prod = ValueNotifier('$pre|');
  static final ValueNotifier<String> shop = ValueNotifier('$pre|');
  static Timer? _t;
  static int _users = 0;
  static final _st = {'prod': _TState(), 'shop': _TState()};

  static List<String> _prodWords() {
    final w = <String>[];
    for (final p in AppState.I.prods) {
      if (p.hidden || p.stock == 'out' || p.name.isEmpty) continue;
      final n = p.name.split(RegExp(r'[\s(]'))[0];
      if (n.length >= 2 && n.length <= 14 && !w.contains(n)) w.add(n);
    }
    w.shuffle();
    final out = w.take(8).toList();
    for (final b in _base) {
      if (out.length < 10 && !out.contains(b)) out.add(b);
    }
    return out;
  }

  static List<String> _shopWords() {
    final w = <String>[];
    for (final s in AppState.I.shops) {
      if (s.hidden || s.name.isEmpty) continue;
      var n = s.name.trim();
      if (n.length > 22) n = n.substring(0, 22);
      if (!w.contains(n)) w.add(n);
    }
    if (w.isEmpty) return ['மளிகைக் கடை', 'காய்கறிக் கடை', 'பேக்கரி'];
    w.shuffle();
    return w;
  }

  static int _step(String k) {
    final st = _st[k]!;
    if (st.list.isEmpty) {
      st.list = k == 'prod' ? _prodWords() : _shopWords();
      st.wi = 0;
      st.ci = 0;
      st.dir = 1;
    }
    final g = st.list[st.wi].characters.toList();
    if (st.hold > 0) {
      st.hold--;
    } else if (st.dir > 0) {
      st.ci++;
      if (st.ci >= g.length) {
        st.dir = -1;
        st.hold = 6;
      }
    } else {
      st.ci--;
      if (st.ci <= 0) {
        st.ci = 0;
        st.dir = 1;
        st.hold = 2;
        st.wi++;
        if (st.wi >= st.list.length) st.list = [];
      }
    }
    final txt = pre + g.take(st.ci).join() + (st.ci >= g.length ? '"' : '|');
    (k == 'prod' ? prod : shop).value = txt;
    return st.hold > 0 ? 220 : (st.dir > 0 ? 160 : 70);
  }

  static void _tick() {
    if (_users <= 0) return;
    final d = _step('prod');
    _step('shop');
    _t = Timer(Duration(milliseconds: d), _tick);
  }

  static void attach() {
    _users++;
    if (_users == 1) _t = Timer(const Duration(milliseconds: 1200), _tick);
  }

  static void detach() {
    _users--;
    if (_users <= 0) {
      _users = 0;
      _t?.cancel();
    }
  }
}

class _TState {
  List<String> list = [];
  int wi = 0, ci = 0, dir = 1, hold = 0;
}

// ═══ ஒரு கடை pill (தேடல் முடிவுகளில்) ═══
class ShopPill extends StatelessWidget {
  final Shop sh;
  const ShopPill(this.sh, {super.key});
  @override
  Widget build(BuildContext context) {
    final d = S.shopDistText(sh);
    return GestureDetector(
      onTap: () => Nav.openShop(sh.id),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: P.card, border: Border.all(color: P.bd), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: P.gc, borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: sh.logoImage.isNotEmpty ? Img(sh.logoImage, emoji: '🏪') : Center(child: Text(sh.logoEmoji('🏪'), style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(height: 6),
          Text(sh.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, w: w8)),
          Text('${sh.isOpenNow ? '🟢 திறந்துள்ளது' : '🔴 மூடியுள்ளது'}${d.isNotEmpty ? ' · $d' : ''}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11.5, w: w7, c: P.mu)),
        ]),
      ),
    );
  }
}

Widget shopPillRow(List<Shop> l) => SizedBox(
      height: 112,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), children: l.map((s) => ShopPill(s)).toList()),
    );

Widget srH(String t) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text(t, style: ts(14.5, w: w8, c: P.mu2)));

Widget chipBtn(String label, VoidCallback onTap, {bool on = false, Widget? trail}) => GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? P.gc : P.card,
          border: Border.all(color: on ? P.g : P.bd, width: 1.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, w: w7, c: on ? P.g2 : P.text))),
          if (trail != null) ...[const SizedBox(width: 5), trail],
        ]),
      ),
    );

// ═══ தேடல் முகப்பு: சமீபத்தியவை, பரிந்துரை, வகைகள், அருகிலுள்ள கடைகள் ═══
class SearchHomeView extends StatefulWidget {
  final void Function(String q) onCommit;
  const SearchHomeView({super.key, required this.onCommit});
  @override
  State<SearchHomeView> createState() => _SearchHomeViewState();
}

class _SearchHomeViewState extends State<SearchHomeView> {
  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final h = SrHist.get();
    final pop = SearchEngine.popular();
    final ix = SearchEngine.index();
    final cats = ix.cats.where((c) => c.type == 'cat').take(12).toList();
    final near = SearchEngine.nearShops();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (h.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
          child: Row(children: [
            Expanded(child: Text('சமீபத்திய தேடல்கள்', style: ts(15, w: w8))),
            TextButton(onPressed: () => setState(SrHist.clear), child: Text('அனைத்தையும் அழி', style: ts(12.5, w: w8, c: P.g2))),
          ]),
        ),
        for (var i = 0; i < h.length; i++)
          InkWell(
            onTap: () => widget.onCommit(h[i]),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
              child: Row(children: [
                Icon(Icons.history, size: 20, color: P.mu),
                const SizedBox(width: 12),
                Expanded(child: Text(h[i], style: ts(14.5, w: w6))),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close, size: 18, color: P.mu),
                  onPressed: () => setState(() => SrHist.del(i)),
                ),
              ]),
            ),
          ),
      ],
      if (pop.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 10), child: Text('பரிந்துரைக்கப்படும் தேடல்கள்', style: ts(15, w: w8))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(children: pop.map((x) => chipBtn('🔍 $x', () => widget.onCommit(x))).toList()),
        ),
      ],
      if (cats.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10), child: Text('வகைகள்', style: ts(15, w: w8))),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          mainAxisSpacing: 10,
          crossAxisSpacing: 8,
          childAspectRatio: .78,
          children: cats
              .map((c) => GestureDetector(
                    onTap: () => widget.onCommit(c.c!.n),
                    child: Column(children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(color: P.card2, borderRadius: BorderRadius.circular(16), border: Border.all(color: P.bd)),
                          clipBehavior: Clip.antiAlias,
                          child: c.c!.photo.isNotEmpty
                              ? Img(c.c!.photo, emoji: c.c!.e.isNotEmpty ? c.c!.e : '🏷️', fit: BoxFit.cover)
                              : Center(child: Text(c.c!.e.isNotEmpty ? c.c!.e : '🏷️', style: const TextStyle(fontSize: 30))),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(c.c!.n, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: ts(12, w: w8, h: 1.25)),
                    ]),
                  ))
              .toList(),
        ),
      ],
      if (near.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 10), child: Text('அருகிலுள்ள கடைகள்', style: ts(15, w: w8))),
        shopPillRow(near),
      ],
      const SizedBox(height: 40),
    ]);
  }
}

// ═══ பரிந்துரைகள் (எழுதும்போது) ═══
class SuggestView extends StatelessWidget {
  final String q;
  final void Function(String q) onCommit;
  final void Function(String text) onFill;
  const SuggestView({super.key, required this.q, required this.onCommit, required this.onFill});

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final sg = SearchEngine.suggestions(q);
    final n = SearchEngine.searchProducts(q).length;
    const lb = {'p': 'பொருள்', 'c': 'வகை', 'k': 'கடை வகை', 'b': 'பிராண்ட்', 's': 'கடை'};
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        onTap: () => onCommit(q),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(color: P.gc, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Text('🔍', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(child: Text('"$q"', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(15, w: w8))),
            Text(n > 0 ? '$n பொருட்கள் — எல்லாம் பார் ›' : 'தேடு ›', style: ts(12.5, w: w8, c: P.g2)),
          ]),
        ),
      ),
      for (final s in sg)
        InkWell(
          onTap: () {
            final g = s['g'];
            if (g == 's') {
              SrHist.add(s['label']!);
              Nav.openShop(s['id']!);
            } else if (g == 'k') {
              SrHist.add(s['label']!);
              Nav.pickType(s['id']!);
            } else {
              onCommit(s['q']!);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: P.card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: P.bd)),
                clipBehavior: Clip.antiAlias,
                child: Img(s['img'] ?? '', emoji: s['e'] ?? '🛒', emojiSize: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s['label']!, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14.5, w: w8)),
                  Text(lb[s['g']] ?? '', style: ts(11.5, w: w7, c: P.mu)),
                ]),
              ),
            ]),
          ),
        ),
      const SizedBox(height: 40),
    ]);
  }
}

// ═══ முடிவுகள் + வடிகட்டு + வரிசை ═══
class SrCtl {
  SrF F = SrF();
  String sort = 'rel';
  int limit = 20;
  void reset() {
    F = SrF();
    sort = 'rel';
    limit = 20;
  }
}

class ResultsView extends StatefulWidget {
  final String q;
  final SrCtl ctl;
  final void Function(String q) onCommit;
  const ResultsView({super.key, required this.q, required this.ctl, required this.onCommit});
  @override
  State<ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<ResultsView> {
  SrCtl get c => widget.ctl;

  void _set(VoidCallback f) => setState(f);

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final q = widget.q.trim();
    final all = SearchEngine.searchProducts(q);
    final f = SearchEngine.applyFilters(all, c.F);
    final shopsHit = SearchEngine.searchShops(q).take(3).toList();
    final fc = c.F.count;
    final sorted = SearchEngine.sortResults(f, c.sort);
    final groups = SearchEngine.group(sorted);
    final shown = groups.take(c.limit).toList();
    final sopts = SearchEngine.sortOptions(all);
    final sl = (sopts.where((o) => o[0] == c.sort).first0 ?? sopts[0])[1];
    final chips = _chips();

    final kids = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 4),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('"$q"', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(15.5, w: w8)),
              Text('${f.length} பொருட்கள்${groups.length != f.length ? ' · ${groups.length} வகை' : ''}', style: ts(12, w: w7, c: P.mu)),
            ]),
          ),
          if (all.isNotEmpty) ...[
            _barBtn(Icons.tune, 'வடிகட்டு', on: fc > 0, badge: fc, onTap: () => _openFilter(all)),
            const SizedBox(width: 6),
            _barBtn(Icons.swap_vert, c.sort == 'rel' ? 'வரிசை' : sl.split(':')[0], onTap: () => _openSort(sopts)),
          ],
        ]),
      ),
      if (chips.isNotEmpty) SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(14, 6, 6, 0), children: chips)),
    ];
    if (shopsHit.isNotEmpty) {
      kids.add(srH('கடைகள்'));
      kids.add(shopPillRow(shopsHit));
    }
    if (groups.isNotEmpty) {
      if (shopsHit.isNotEmpty) kids.add(srH('பொருட்கள்'));
      kids.addAll(shown.map((g) => SrCard(g)));
      if (groups.length > c.limit) {
        kids.add(Padding(
          padding: const EdgeInsets.all(14),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), side: BorderSide(color: P.g), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => _set(() => c.limit += 20),
            child: Text('மேலும் காட்டு (${groups.length - c.limit})', style: ts(14, w: w8, c: P.g2)),
          ),
        ));
      }
    } else if (all.isNotEmpty && fc > 0) {
      kids.add(Padding(
        padding: const EdgeInsets.all(30),
        child: Column(children: [
          Text('இந்த வடிகட்டலில் பொருள் இல்லை', style: ts(15, w: w8)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => _set(() => c.F = SrF()), child: Text('வடிகட்டலை நீக்கு', style: ts(13.5, w: w8, c: P.g2))),
        ]),
      ));
    } else if (shopsHit.isEmpty) {
      kids.add(NoResult(q: q, onCommit: widget.onCommit));
    }
    kids.add(const SizedBox(height: 60));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids);
  }

  Widget _barBtn(IconData ic, String label, {bool on = false, int badge = 0, required VoidCallback onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: on ? P.gc : P.card,
            border: Border.all(color: on ? P.g : P.bd, width: 1.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ic, size: 17, color: on ? P.g2 : P.mu2),
            const SizedBox(width: 4),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 90), child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12.5, w: w8, c: on ? P.g2 : P.text))),
            if (badge > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: P.g, borderRadius: BorderRadius.circular(10)),
                child: Text('$badge', style: ts(11, w: w8, c: Colors.white)),
              ),
            ],
          ]),
        ),
      );

  List<Widget> _chips() {
    final F = c.F, out = <Widget>[];
    void x(String lab, VoidCallback f) => out.add(chipBtn(lab, () => _set(f), on: true, trail: Text('✕', style: ts(11, w: w8, c: P.g2))));
    for (final v in List.of(F.shop)) {
      x(S.shopById(v)?.name ?? v, () => F.shop.remove(v));
    }
    for (final k in ['cat', 'brand', 'pack']) {
      for (final v in List.of(F.listOf(k))) {
        x(v, () => F.listOf(k).remove(v));
      }
    }
    if (F.price != '') {
      final i = int.tryParse(F.price) ?? 0;
      x(seBucketLabel(kPriceBuckets[i.clamp(0, kPriceBuckets.length - 1).toInt()]), () => F.price = '');
    }
    if (F.offer) x('🏷️ சலுகை', () => F.offer = false);
    if (F.open) x('🟢 திறந்த கடைகள்', () => F.open = false);
    if (F.near) x('📍 அருகில்', () => F.near = false);
    if (F.avail) x('✅ கையிருப்பு உள்ளது', () => F.avail = false);
    if (F.fast) x('🛵 விரைவு டெலிவரி', () => F.fast = false);
    if (F.rate) x('⭐ 4+', () => F.rate = false);
    F.attr.forEach((k, l) {
      for (final v in List.of(l)) {
        x('$k: $v', () => l.remove(v));
      }
    });
    if (out.length > 1) out.add(chipBtn('அனைத்தையும் நீக்கு', () => _set(() => c.F = SrF())));
    return out;
  }

  Future<void> _openSort(List<List<String>> opts) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: P.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (b) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _Grab(),
          Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 8), child: Text('வரிசைப்படுத்து', style: ts(17, w: w8))),
          for (final o in opts)
            InkWell(
              onTap: () => Navigator.pop(b, o[0]),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(children: [
                  Expanded(child: Text(o[1], style: ts(15, w: c.sort == o[0] ? w8 : w6, c: c.sort == o[0] ? P.g2 : P.text))),
                  Icon(c.sort == o[0] ? Icons.radio_button_checked : Icons.radio_button_off, color: c.sort == o[0] ? P.g : P.mu),
                ]),
              ),
            ),
          const SizedBox(height: 10),
        ]),
      ),
    );
    if (v != null) _set(() => c.sort = v);
  }

  Future<void> _openFilter(List<SeHit> all) async {
    final draft = c.F.copy();
    final av = SearchEngine.availableFilters(all);
    final res = await showModalBottomSheet<SrF>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: P.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (b) => StatefulBuilder(builder: (b, setS) {
        final n = SearchEngine.applyFilters(all, draft).length;
        Widget sec(String title, List<FOpt>? opts, bool multi, String k) {
          if (opts == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: ts(14.5, w: w8)),
              const SizedBox(height: 8),
              Wrap(
                children: opts.map((o) {
                  final on = multi ? draft.listOf(k).contains(o.v) : draft.price == o.v;
                  return chipBtn(o.l, () {
                    setS(() {
                      if (multi) {
                        final l = draft.listOf(k);
                        if (l.contains(o.v)) {
                          l.remove(o.v);
                        } else {
                          l.add(o.v);
                        }
                      } else {
                        draft.price = draft.price == o.v ? '' : o.v;
                      }
                    });
                  }, on: on, trail: Text('${o.n}', style: ts(11, w: w7, c: P.mu)));
                }).toList(),
              ),
            ]),
          );
        }

        final body = <Widget>[
          if (av.quick != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('விரைவு வடிகட்டல்', style: ts(14.5, w: w8)),
                const SizedBox(height: 8),
                Wrap(children: av.quick!.map((q) => chipBtn(q[1], () => setS(() => draft.toggleQuick(q[0])), on: draft.quick(q[0]))).toList()),
              ]),
            ),
          sec('விலை', av.price, false, 'price'),
          sec('கடை', av.shop, true, 'shop'),
          sec('வகை', av.cat, true, 'cat'),
          sec('பிராண்ட்', av.brand, true, 'brand'),
          sec('அளவு', av.pack, true, 'pack'),
          for (final a in av.attr ?? <AttrF>[])
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.k, style: ts(14.5, w: w8)),
                const SizedBox(height: 8),
                Wrap(
                  children: a.opts.map((o) {
                    final l = draft.attr[a.k] ?? [];
                    return chipBtn(o.l, () {
                      setS(() {
                        final ll = draft.attr.putIfAbsent(a.k, () => []);
                        if (ll.contains(o.v)) {
                          ll.remove(o.v);
                        } else {
                          ll.add(o.v);
                        }
                      });
                    }, on: l.contains(o.v), trail: Text('${o.n}', style: ts(11, w: w7, c: P.mu)));
                  }).toList(),
                ),
              ]),
            ),
        ];
        final empty = av.quick == null && av.price == null && av.shop == null && av.cat == null && av.brand == null && av.pack == null && av.attr == null;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(b).size.height * .82),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const _Grab(),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 8, 0),
                child: Row(children: [
                  Expanded(child: Text('வடிகட்டு', style: ts(17, w: w8))),
                  TextButton(onPressed: () => setS(() => draft
                    ..shop.clear()
                    ..cat.clear()
                    ..brand.clear()
                    ..pack.clear()
                    ..price = ''
                    ..offer = false
                    ..open = false
                    ..near = false
                    ..avail = false
                    ..fast = false
                    ..rate = false
                    ..attr.clear()), child: Text('அனைத்தையும் அழி', style: ts(13, w: w8, c: P.g2))),
                ]),
              ),
              Flexible(
                child: empty
                    ? Padding(padding: const EdgeInsets.all(30), child: Text('இந்த முடிவுகளுக்கு வடிகட்டல் தேவையில்லை', textAlign: TextAlign.center, style: ts(14, c: P.mu)))
                    : ListView(shrinkWrap: true, children: [...body, const SizedBox(height: 12)]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: P.bd), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => Navigator.pop(b),
                      child: Text('ரத்து', style: ts(15, w: w8, c: P.mu2)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: GreenButton('$n பொருட்களைக் காட்டு', height: 50, onTap: () => Navigator.pop(b, draft))),
                ]),
              ),
            ]),
          ),
        );
      }),
    );
    if (res != null) {
      _set(() {
        c.F = res;
        c.limit = 20;
      });
    }
  }
}

class _Grab extends StatelessWidget {
  const _Grab();
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 10, bottom: 10),
          width: 42,
          height: 5,
          decoration: BoxDecoration(color: P.bd, borderRadius: BorderRadius.circular(3)),
        ),
      );
}

// ஒரே பொருள், பல கடை → ஒரே card; ஒவ்வொரு கடைக்கும் ஒரு வரி
class SrCard extends StatelessWidget {
  final List<SeHit> grp;
  const SrCard(this.grp, {super.key});

  @override
  Widget build(BuildContext context) {
    final it = grp[0].it, p = it.p;
    final off = grp.any((r) => r.it.off);
    final packs = <String>[];
    for (final r in grp) {
      for (final w in r.it.packs) {
        if (!packs.contains(w)) packs.add(w);
      }
    }
    final sub = '${packs.take(3).join(' · ')}${packs.length > 3 ? ' +${packs.length - 3}' : ''}${it.cat != null ? ' · ${it.cat!.n}' : ''}';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(color: P.card, border: Border.all(color: P.bd), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        InkWell(
          onTap: () => Nav.goProd(p),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(children: [
                  Container(
                    decoration: BoxDecoration(color: P.card2, borderRadius: BorderRadius.circular(12)),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox.expand(child: Img(p.photo, emoji: p.emoji, emojiSize: 30)),
                  ),
                  if (off)
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: const BoxDecoration(color: Color(0xFFE8590C), borderRadius: BorderRadius.only(topLeft: Radius.circular(12), bottomRight: Radius.circular(8))),
                        child: Text('சலுகை', style: ts(9.5, w: w8, c: Colors.white)),
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (p.brand.isNotEmpty && !it.n.contains(it.b)) Text(p.brand.toUpperCase(), style: ts(10.5, w: w7, c: P.mu2, ls: .4)),
                  Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(14.5, w: w8, h: 1.3)),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, w: w6, c: P.mu)),
                  if (grp.length > 1)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: P.gc, borderRadius: BorderRadius.circular(8)),
                      child: Text('${grp.length} கடைகளில் கிடைக்கும் — விலையை ஒப்பிடுங்கள்', style: ts(11.5, w: w8, c: P.g2)),
                    ),
                ]),
              ),
            ]),
          ),
        ),
        for (final r in grp) _SrShopRow(r),
      ]),
    );
  }
}

class _SrShopRow extends StatelessWidget {
  final SeHit r;
  const _SrShopRow(this.r);
  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final it = r.it, p = it.p, sh = it.sh;
    final open = sh.isOpenNow, d = S.shopDistText(sh);
    final eta = sh.deliveryAvailable && sh.etaKnown ? '${sh.etaText} நிமி' : '';
    final one = p.packs.length == 1;
    final o = p.packs[0].offer;
    final inCart = S.totalQtyOf(p);
    final meta = [
      if (!open) '🔴 மூடியுள்ளது',
      if (d.isNotEmpty) '📍 $d',
      if (eta.isNotEmpty) '🛵 $eta',
      if (!it.avail) '❌ கையிருப்பு இல்லை' else if (p.stock == 'low') '⚠️ குறைவான கையிருப்பு',
    ].join(' · ');
    Widget btn;
    if (!it.avail) {
      btn = const OosTag(small: true, text: 'இல்லை');
    } else if (one) {
      btn = HxBtn(p, 0);
    } else {
      btn = GestureDetector(
        onTap: () => Nav.openProduct(p),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(border: Border.all(color: P.g, width: 1.4), borderRadius: BorderRadius.circular(9), color: P.card),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (inCart > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: P.g, borderRadius: BorderRadius.circular(8)),
                child: Text('$inCart', style: ts(11, w: w8, c: Colors.white)),
              ),
              const SizedBox(width: 4),
            ],
            Text('அளவு ›', style: ts(12, w: w8, c: P.g2)),
          ]),
        ),
      );
    }
    return Opacity(
      opacity: open && it.avail ? 1 : .7,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: P.bd))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.storefront_outlined, size: 15, color: P.g2),
                const SizedBox(width: 4),
                Flexible(child: Text(sh.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, w: w8))),
              ]),
              if (meta.isNotEmpty) Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(11.5, w: w6, c: P.mu)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${rupee(it.minP)}', style: pop(15)),
            if (one && o != null) Text('₹${rupee(o.mrp)}', style: ts(11, c: P.mu, deco: TextDecoration.lineThrough)),
            if (!one) Text('முதல்', style: ts(10.5, w: w7, c: P.mu)),
          ]),
          const SizedBox(width: 10),
          btn,
        ]),
      ),
    );
  }
}

// "எதுவும் கிடைக்கவில்லை": இதைத் தேடினீர்களா? · வகைகள் · தொடர்புடையவை · அருகிலுள்ள கடைகள்
class NoResult extends StatelessWidget {
  final String q;
  final void Function(String) onCommit;
  const NoResult({super.key, required this.q, required this.onCommit});
  @override
  Widget build(BuildContext context) {
    final dym = SearchEngine.didYouMean(q), rel = SearchEngine.related(q);
    final near = SearchEngine.nearShops();
    final cats = SearchEngine.index().cats.where((c) => c.type == 'cat').take(8).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(children: [
          const Text('🔍', style: TextStyle(fontSize: 38)),
          const SizedBox(height: 6),
          Text('"$q" — எதுவும் கிடைக்கவில்லை', textAlign: TextAlign.center, style: ts(15.5, w: w8)),
          if (dym.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Padding(padding: const EdgeInsets.only(right: 6, bottom: 8), child: Text('இதைத் தேடினீர்களா?', style: ts(13, w: w7, c: P.mu2))),
              ...dym.map((d) => chipBtn(d, () => onCommit(d), on: true)),
            ]),
          ],
          if (cats.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('இவற்றைப் பாருங்கள்:', style: ts(12.5, w: w7, c: P.mu)),
            const SizedBox(height: 8),
            Wrap(alignment: WrapAlignment.center, children: cats.map((c) => chipBtn('${c.c!.e.isNotEmpty ? c.c!.e : '🏷️'} ${c.c!.n}', () => onCommit(c.c!.n))).toList()),
          ],
        ]),
      ),
      if (rel.isNotEmpty) ...[
        srH('தொடர்புடைய பொருட்கள்'),
        SizedBox(
          height: 236,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), children: rel.map((p) => HxCard(p, 0)).toList()),
        ),
      ],
      if (near.isNotEmpty) ...[srH('அருகிலுள்ள கடைகள்'), shopPillRow(near)],
      Padding(
        padding: const EdgeInsets.all(16),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), side: BorderSide(color: P.g), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () => Nav.go('shops'),
          child: Text('🏪 எல்லா கடைகளையும் பார்', style: ts(14, w: w8, c: P.g2)),
        ),
      ),
    ]);
  }
}

// ═══ கடைக்குள் தேடல் (அந்தக் கடை மட்டும்) ═══
class ShopSearchScreen extends StatefulWidget {
  final String shopId;
  final String initial;
  const ShopSearchScreen({super.key, required this.shopId, this.initial = ''});
  @override
  State<ShopSearchScreen> createState() => _ShopSearchScreenState();
}

class _ShopSearchScreenState extends State<ShopSearchScreen> {
  late final TextEditingController _q = TextEditingController(text: widget.initial);
  final _f = FocusNode();
  Timer? _deb, _hist;
  String _cur = '';

  @override
  void initState() {
    super.initState();
    _cur = widget.initial;
    TypingHint.attach();
    WidgetsBinding.instance.addPostFrameCallback((_) => _f.requestFocus());
  }

  @override
  void dispose() {
    TypingHint.detach();
    _deb?.cancel();
    _hist?.cancel();
    _q.dispose();
    _f.dispose();
    super.dispose();
  }

  void _on(String v) {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 90), () => setState(() => _cur = v));
    _hist?.cancel();
    _hist = Timer(const Duration(milliseconds: 1500), () {
      if (_q.text.trim() == v.trim()) SrHist.add(v);
    });
  }

  void _set(String v) {
    _q.text = v;
    _q.selection = TextSelection.collapsed(offset: v.length);
    setState(() => _cur = v);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final sh = S.shopById(widget.shopId);
    return Scaffold(
      backgroundColor: P.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Container(
            color: P.card,
            padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
            child: Row(children: [
              IconButton(icon: Icon(Icons.arrow_back, color: P.text), onPressed: () => Navigator.of(context).maybePop()),
              Expanded(
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: P.card3, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    const Text('🔍'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ValueListenableBuilder<String>(
                        valueListenable: TypingHint.prod,
                        builder: (_, hint, __) => TextField(
                          controller: _q,
                          focusNode: _f,
                          onChanged: _on,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _f.unfocus(),
                          style: ts(15.5, w: w6),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: _f.hasFocus ? 'பொருளை தேடுங்கள்...' : hint,
                            hintStyle: ts(15, w: w6, c: P.mu),
                          ),
                        ),
                      ),
                    ),
                    if (_cur.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _set('');
                          _f.requestFocus();
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(color: P.bd, shape: BoxShape.circle),
                          child: Icon(Icons.close, size: 16, color: P.mu2),
                        ),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
          Expanded(child: _body(sh)),
        ]),
      ),
    );
  }

  Widget _body(Shop? sh) {
    final q = _cur;
    if (getSearchTokens(q).isEmpty) {
      final h = SrHist.get();
      return ListView(padding: const EdgeInsets.all(16), children: [
        Padding(padding: const EdgeInsets.all(14), child: Text('பொருளை தேட ஆரம்பிக்கவும்...', textAlign: TextAlign.center, style: ts(15, c: P.mu))),
        if (h.isNotEmpty) ...[
          Text('சமீபத்திய தேடல்கள்', style: ts(14, w: w8)),
          const SizedBox(height: 8),
          ...h.map((x) => ListTile(dense: true, leading: const Text('🕘'), title: Text(x, style: ts(14.5, w: w6)), onTap: () => _set(x))),
        ],
      ]);
    }
    final r = SearchEngine.searchProducts(q, shopId: widget.shopId).map((x) => x.it.p).toList();
    if (r.isEmpty) {
      final dym = SearchEngine.didYouMean(q);
      final other = <String, int>{};
      for (final x in SearchEngine.searchProducts(q)) {
        if (x.it.sh.id != widget.shopId) other[x.it.sh.id] = (other[x.it.sh.id] ?? 0) + 1;
      }
      return ListView(padding: const EdgeInsets.all(20), children: [
        const Center(child: Text('🔍', style: TextStyle(fontSize: 34))),
        const SizedBox(height: 6),
        Text('இந்தக் கடையில் "$q" இல்லை', textAlign: TextAlign.center, style: ts(15, w: w8)),
        if (dym.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(alignment: WrapAlignment.center, children: [
            Padding(padding: const EdgeInsets.only(right: 6, top: 8), child: Text('இதைத் தேடினீர்களா?', style: ts(13, w: w7, c: P.mu2))),
            ...dym.map((d) => chipBtn(d, () => _set(d), on: true)),
          ]),
        ],
        const SizedBox(height: 12),
        if (other.isNotEmpty) ...[
          Text('மற்ற கடைகளில் கிடைக்கிறது:', textAlign: TextAlign.center, style: ts(12.5, w: w7, c: P.mu)),
          const SizedBox(height: 8),
          ...other.entries.map((e) {
            final o = S.shopById(e.key);
            return Card(
              color: P.card,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: P.bd)),
              child: ListTile(
                title: Text('🏪 ${o?.name ?? e.key}', style: ts(14, w: w8)),
                trailing: Text('${e.value} பொருட்கள் ›', style: ts(12.5, w: w8, c: P.g2)),
                onTap: () {
                  // HTML: closeSearch(); selectShop(id) — இப்போதைய கடையை மாற்று, அடுக்காதே
                  Navigator.of(context).pop();
                  Nav.replaceShop(e.key);
                  Future.delayed(const Duration(milliseconds: 350), () => Nav.push(ShopSearchScreen(shopId: e.key, initial: q)));
                },
              ),
            );
          }),
        ] else
          Text('வேறு பெயரில் தேடிப் பாருங்கள்', textAlign: TextAlign.center, style: ts(12.5, c: P.mu)),
      ]);
    }
    return ListView(padding: const EdgeInsets.only(bottom: 40), children: [
      if (sh != null)
        Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 6), child: Text('🏪 ${sh.name} · ${r.length} பொருட்கள்', style: ts(13, w: w8, c: P.mu2))),
      ...r.take(50).map((p) => _ShopSrItem(p)),
      if (r.length > 50) Padding(padding: const EdgeInsets.all(14), child: Text('முதல் 50 மட்டும் — மேலும் சுருக்கித் தேடுங்கள்', textAlign: TextAlign.center, style: ts(12, c: P.mu))),
    ]);
  }
}

class _ShopSrItem extends StatelessWidget {
  final Product p;
  const _ShopSrItem(this.p);
  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: P.card, border: Border.all(color: P.bd), borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => Nav.openProduct(p),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: P.card2, borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: Img(p.photo, emoji: p.emoji, emojiSize: 30),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (p.brand.isNotEmpty) Text(p.brand.toUpperCase(), style: ts(11.5, w: w7, c: P.cyan, ls: .5)),
            GestureDetector(onTap: () => Nav.openProduct(p), child: Text(p.name, style: ts(14.5, w: w8))),
            const SizedBox(height: 4),
            for (var i = 0; i < p.packs.length; i++) _packRow(p, i),
          ]),
        ),
      ]),
    );
  }

  Widget _packRow(Product p, int i) {
    final pk = p.packs[i];
    final q = S.qtyOf(p, i);
    final o = pk.offer;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
            Text('${pk.w.isNotEmpty ? '${pk.w} · ' : ''}₹${rupee(pk.price)}', style: ts(13.5, w: w7)),
            if (o != null) Text('₹${rupee(o.mrp)}', style: ts(12, c: P.mu, deco: TextDecoration.lineThrough)),
            if (o != null) Text('${o.off}% தள்ளுபடி', style: ts(11.5, w: w8, c: const Color(0xFF16A34A))),
          ]),
        ),
        q > 0
            ? QtyStepper(qty: q, height: 32, btnW: 32, font: 14, onMinus: () => CartOps.chg(p, i, -1), onPlus: () => CartOps.chg(p, i, 1))
            : GestureDetector(
                onTap: () => CartOps.add(p, i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(border: Border.all(color: P.g, width: 1.5), borderRadius: BorderRadius.circular(9)),
                  child: Text('+ சேர்', style: ts(12.5, w: w8, c: P.g2)),
                ),
              ),
      ]),
    );
  }
}
