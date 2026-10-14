// Crispy — அறிவிப்புகள்: ஆர்டர் நிலைகள், கடை சலுகைகள், புதிய கடைகள் (இந்த phone-ல் உள்ள தரவிலிருந்தே)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../nav.dart';
import '../orders.dart';
import '../state.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';
import 'orders.dart';

class NtEv {
  final String id, cat, k, t;
  final int ts;
  final List<String> s;
  final String? actLb;
  final VoidCallback go;
  final VoidCallback? act;
  NtEv(this.id, this.ts, this.cat, this.k, this.t, this.s, this.go, {this.actLb, this.act});
}

const Map<String, IconData> _ic = {
  'placed': Icons.receipt_long,
  'acc': Icons.storefront,
  'ready': Icons.shopping_bag,
  'out': Icons.delivery_dining,
  'done': Icons.check_circle,
  'cancel': Icons.cancel,
  'sent': Icons.send,
  'offer': Icons.local_offer,
  'shop': Icons.notifications,
};
const Map<String, Color> _col = {
  'placed': AppColors.primary,
  'acc': Color(0xFF2563EB),
  'ready': Color(0xFFF59E0B),
  'out': Color(0xFF0EA5E9),
  'done': Color(0xFF16A34A),
  'cancel': Color(0xFFDC2626),
  'sent': AppColors.primary,
  'offer': Color(0xFFE11D48),
  'shop': Color(0xFF64748B),
};

class Nt {
  static int geti(String k) => Store.number(k).toInt();
  static void put(String k, int v) => Store.setStr(k, '$v');

  static List<NtEv> events() {
    final ev = <NtEv>[];
    void track(OrderV o) {
      if (o.cloud && o.id != null) {
        Nav.go('orders');
        Nav.push(OrderDetailScreen(id: o.id), hl: 'orders');
      } else {
        Nav.go('orders');
      }
    }

    for (final o in Orders.I.build()) {
      final no = o.no, tot = '₹${rupee(o.tot)}', shop = o.shop;
      if (!o.cloud) {
        ev.add(NtEv('s$no', o.ts, 'ord', 'sent', 'ஆர்டர் WhatsApp-ல் அனுப்பப்பட்டது', ['$no${shop.isNotEmpty ? ' · $shop' : ''} · $tot'], () => track(o)));
        continue;
      }
      int tm(String? x) => DateTime.tryParse(x ?? '')?.millisecondsSinceEpoch ?? 0;
      final st = <String, int>{'c': tm(o.t['c']) > 0 ? tm(o.t['c']) : o.ts, 'a': tm(o.t['a']), 'r': tm(o.t['r']), 'p': tm(o.t['p']), 'd': tm(o.t['d']), 'x': tm(o.t['x'])};
      const curOf = {'ORDER_RECEIVED': 'c', 'SHOP_ACCEPTED': 'a', 'PREPARING': 'a', 'READY_FOR_PICKUP': 'r', 'DELIVERY_ASSIGNED': 'r', 'OUT_FOR_DELIVERY': 'p', 'DELIVERED': 'd', 'CANCELLED': 'x'};
      final cur = curOf[o.status];
      if (cur != null && st[cur] == 0) {
        final m = [st['c']!, st['a']!, st['r']!, st['p']!, st['d']!].reduce((a, b) => a > b ? a : b);
        st[cur] = m > 0 ? m : o.ts;
      }
      void add(String key, String k, String cat, String t, List<String> sub, {String? lb, bool act = false}) {
        if ((st[key] ?? 0) > 0) ev.add(NtEv('$key$no', st[key]!, cat, k, t, sub, () => track(o), actLb: act ? lb : null, act: act ? () => track(o) : null));
      }

      add('c', 'placed', 'ord', 'ஆர்டர் பெறப்பட்டது', ['$no${shop.isNotEmpty ? ' · $shop' : ''} · $tot'], lb: 'ஆர்டரைப் பார்க்க', act: true);
      add('a', 'acc', 'ord', '${shop.isNotEmpty ? shop : 'கடை'} உங்கள் ஆர்டரை ஏற்றுக்கொண்டது', ['$no · $tot']);
      add('r', 'ready', 'ord', 'உங்கள் பார்சல் தயாராகிவிட்டது', ['$no${shop.isNotEmpty ? ' · $shop' : ''}']);
      add('p', 'out', 'dlv', 'உங்கள் ஆர்டர் டெலிவரிக்குப் புறப்பட்டது', ['$no${o.dpName.isNotEmpty ? ' · டெலிவரி: ${o.dpName}' : ''}'], lb: '📍 டிராக்கிங்', act: o.status == 'OUT_FOR_DELIVERY');
      add('d', 'done', 'dlv', 'ஆர்டர் வெற்றிகரமாக வழங்கப்பட்டது', ['$no · $tot']);
      add('x', 'cancel', 'ord', 'ஆர்டர் ரத்து செய்யப்பட்டது', ['$no · $tot']);
    }
    // கடை சலுகை: இந்த phone முதல் முறை பார்த்த நேரம்
    final so = Store.json(K.ntOff);
    final seenOff = so is Map ? Map<String, dynamic>.from(so) : <String, dynamic>{};
    var ch = false;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final sh in AppState.I.shops) {
      if (sh.hidden) continue;
      if (sh.offerText.isNotEmpty) {
        final key = '${sh.id}|${sh.offerText}';
        if (seenOff[key] == null) {
          seenOff[key] = now;
          ch = true;
        }
        void go() => Nav.openShop(sh.id);
        ev.add(NtEv('o$key', jz(seenOff[key]).toInt(), 'off', 'offer', 'உங்களுக்கு சிறப்பு சலுகை!', ['${sh.name}: ${sh.offerText}'], go, actLb: 'பார்க்க', act: go));
      }
      final cAt = DateTime.tryParse(sh.createdAt)?.millisecondsSinceEpoch ?? 0;
      if (cAt > 0 && now - cAt < 14 * 864e5) {
        ev.add(NtEv('n${sh.id}', cAt, 'off', 'shop', 'புதிய கடை சேர்க்கப்பட்டுள்ளது', ['${sh.name} இப்போது Crispy ஆப்பில்'], () => Nav.openShop(sh.id)));
      }
    }
    if (ch) Store.setJson(K.ntOff, seenOff);
    final clr = geti(K.ntClr);
    final out = ev.where((e) => e.ts > clr).toList()..sort((a, b) => b.ts.compareTo(a.ts));
    return out;
  }

  static int unread() {
    if (Store.str(K.ntSeen) == null) put(K.ntSeen, DateTime.now().millisecondsSinceEpoch);
    final seen = geti(K.ntSeen);
    return events().where((e) => e.ts > seen).length;
  }
}

class NotifScreen extends StatefulWidget {
  const NotifScreen({super.key});
  @override
  State<NotifScreen> createState() => _NotifScreenState();
}

class _NotifScreenState extends State<NotifScreen> {
  String _tab = 'all';
  late int _seen = Nt.geti(K.ntSeen);

  @override
  void initState() {
    super.initState();
    Orders.I.fetch();
  }

  @override
  void dispose() {
    Nt.put(K.ntSeen, DateTime.now().millisecondsSinceEpoch > Nt.geti(K.ntSeen) ? DateTime.now().millisecondsSinceEpoch : Nt.geti(K.ntSeen));
    Future.microtask(AppState.I.ping);
    super.dispose();
  }

  String _day(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts), t = DateTime.now(), y = t.subtract(const Duration(days: 1));
    bool same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    final dm = taDayMonthYear(d);
    return same(d, t) ? 'இன்று, $dm' : (same(d, y) ? 'நேற்று, $dm' : dm);
  }

  String _time(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts), t = DateTime.now(), y = t.subtract(const Duration(days: 1));
    bool same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    final day = same(d, t) ? 'இன்று' : (same(d, y) ? 'நேற்று' : taDayMon(d));
    return '$day, ${hm12(d)}';
  }

  Future<void> _menu() async {
    final v = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: P.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (b) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: Icon(Icons.done_all, color: P.g2), title: Text('எல்லாம் படித்ததாகக் குறி', style: ts(15, w: w7)), onTap: () => Navigator.pop(b, 'read')),
          ListTile(leading: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)), title: Text('அனைத்தையும் அழி', style: ts(15, w: w7, c: const Color(0xFFDC2626))), onTap: () => Navigator.pop(b, 'clear')),
        ]),
      ),
    );
    if (v == 'read') {
      _seen = DateTime.now().millisecondsSinceEpoch;
      Nt.put(K.ntSeen, _seen);
      setState(() {});
      toast('✓ எல்லாம் படிக்கப்பட்டது');
    } else if (v == 'clear') {
      final ok = await confirmDialog('எல்லா அறிவிப்புகளும் அழிக்கப்படும். உங்கள் ஆர்டர்கள் அழியாது. சரியா?');
      if (!ok) return;
      final n = DateTime.now().millisecondsSinceEpoch;
      Nt.put(K.ntClr, n);
      Nt.put(K.ntSeen, n);
      _seen = n;
      setState(() {});
      toast('🗑️ அறிவிப்புகள் அழிக்கப்பட்டன');
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    return ListenableBuilder(
      listenable: Orders.I,
      builder: (_, __) {
        final ev = Nt.events();
        final cnt = {'all': ev.length, 'ord': ev.where((e) => e.cat == 'ord').length, 'dlv': ev.where((e) => e.cat == 'dlv').length, 'off': ev.where((e) => e.cat == 'off').length};
        final list = _tab == 'all' ? ev : ev.where((e) => e.cat == _tab).toList();
        final un = ev.where((e) => e.ts > _seen).length;
        final kids = <Widget>[];
        var day = '';
        for (final e in list) {
          final d = _day(e.ts);
          if (d != day) {
            day = d;
            kids.add(Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 6), child: Text(d, style: ts(13, w: w8, c: P.mu2))));
          }
          final u = e.ts > _seen;
          kids.add(InkWell(
            onTap: () {
              Navigator.of(context).popUntil((r) => r.isFirst);
              e.go();
            },
            child: Container(
              color: u ? P.gc : null,
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: _col[e.k], shape: BoxShape.circle), child: Icon(_ic[e.k], color: Colors.white, size: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.t, style: ts(14.5, w: w8)),
                    for (final x in e.s) Text(x, style: ts(12.5, c: P.mu2)),
                    const SizedBox(height: 3),
                    Text(_time(e.ts), style: ts(12, c: P.mu)),
                    if (e.actLb != null)
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).popUntil((r) => r.isFirst);
                          e.act!();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(border: Border.all(color: P.g), borderRadius: BorderRadius.circular(16)),
                          child: Text('${e.actLb} ›', style: ts(12.5, w: w8, c: P.g2)),
                        ),
                      ),
                  ]),
                ),
                Column(children: [
                  Icon(Icons.chevron_right, color: P.mu),
                  if (u) Container(width: 9, height: 9, decoration: BoxDecoration(color: e.k == 'offer' ? const Color(0xFFEF4444) : (e.k == 'cancel' ? const Color(0xFFF59E0B) : AppColors.primary), shape: BoxShape.circle)),
                ]),
              ]),
            ),
          ));
        }
        Widget tab(String k, String l) => GestureDetector(
              onTap: () => setState(() => _tab = k),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: _tab == k ? P.g : P.card, border: Border.all(color: _tab == k ? P.g : P.bd), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(l, style: ts(13, w: w8, c: _tab == k ? Colors.white : P.mu2)),
                  const SizedBox(width: 6),
                  Text('${cnt[k]}', style: ts(12, w: w8, c: _tab == k ? Colors.white : P.mu)),
                ]),
              ),
            );
        return Scaffold(
          backgroundColor: P.bg,
          appBar: AppBar(
            backgroundColor: P.card,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(tooltip: 'பின்செல்', icon: Icon(Icons.arrow_back, color: P.text), onPressed: () => Navigator.of(context).maybePop()),
            title: Row(children: [
              Text('அறிவிப்புகள்', style: ts(18, w: w8)),
              if (un > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(10)),
                  child: Text(un > 9 ? '9+' : '$un', style: ts(12, w: w8, c: Colors.white)),
                ),
              ],
            ]),
            actions: [IconButton(icon: Icon(Icons.more_vert, color: P.text), onPressed: _menu)],
          ),
          body: Column(children: [
            SizedBox(
              height: 52,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 10, 4, 6), children: [
                tab('all', 'அனைத்தும்'),
                tab('ord', 'ஆர்டர்கள்'),
                tab('dlv', 'டெலிவரி'),
                tab('off', 'சலுகைகள்'),
              ]),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.notifications_none, size: 56, color: P.mu),
                          const SizedBox(height: 8),
                          Text('அறிவிப்புகள் எதுவும் இல்லை', style: ts(16, w: w8)),
                          Text(_tab == 'off' ? 'கடைகள் சலுகை அறிவித்தால் இங்கே தெரியும்' : 'ஆர்டர் செய்தால் அதன் ஒவ்வொரு நிலையும் இங்கே தெரியும்', textAlign: TextAlign.center, style: ts(13, c: P.mu)),
                        ]),
                      ),
                    )
                  : ListView(padding: const EdgeInsets.only(bottom: 30), children: kids),
            ),
          ]),
        );
      },
    );
  }
}
