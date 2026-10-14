// Crispy — என் ஆர்டர்கள், ஆர்டர் பின்தொடர்தல் (timeline, OTP, delivery நபர்), ரத்து, மீண்டும் வாங்க, ஆர்டர் வெற்றி sheet
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../nav.dart';
import '../orders.dart';
import '../api.dart';
import '../state.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';
import '../push.dart';

Orders get O => Orders.I;

// ═══ ஆர்டர் வெற்றி: ✓, confetti, பின்தொடர ═══
Future<void> showOrderSuccess({required String oNo, required String date, required String shopName, required double sub, required double del, required double tot, required String oid, String ph = ''}) async {
  final c = Nav.ctx;
  if (c == null) return;
  haptic(40);
  final track = await showModalBottomSheet<bool>(
    context: c,
    isScrollControlled: true,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    builder: (b) => _Success(oNo: oNo, date: date, shopName: shopName, sub: sub, del: del, tot: tot, oid: oid, ph: ph),
  );
  if (track == true) {
    if (kUuid.hasMatch(oid)) {
      openTrack(oid);
    } else {
      Nav.go('orders'); // HTML: openOrders()
    }
  }
}

class _Success extends StatefulWidget {
  final String oNo, date, shopName, oid, ph;
  final double sub, del, tot;
  const _Success({required this.oNo, required this.date, required this.shopName, required this.sub, required this.del, required this.tot, this.oid = '', this.ph = ''});
  @override
  State<_Success> createState() => _SuccessState();
}

class _SuccessState extends State<_Success> with TickerProviderStateMixin {
  late final AnimationController _tick = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
  late final AnimationController _cf = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  final _rnd = math.Random();
  late final List<List<double>> _bits = List.generate(34, (i) => [8 + _rnd.nextDouble() * 84, _rnd.nextDouble() * 120 - 60, _rnd.nextDouble() * 720 - 360, _rnd.nextDouble() * .35, i.toDouble()]);
  static const _cols = [AppColors.primary, Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF3B82F6), Color(0xFFA855F7), Color(0xFF16A34A)];

  @override
  void initState() {
    super.initState();
    if (reducedMotion) {
      _tick.value = 1; // அசைவு குறைப்பு: ✓ உடனே, கொண்டாட்டம் இல்லை
      return;
    }
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _cf.forward();
    });
  }

  @override
  void dispose() {
    _tick.dispose();
    _cf.dispose();
    super.dispose();
  }

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [Text(l, style: ts(13.5, c: P.mu2)), const Spacer(), Flexible(child: Text(v, textAlign: TextAlign.right, style: ts(13.5, w: w8)))]),
      );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      decoration: BoxDecoration(color: P.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 26, 20, 18 + mq.padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: ScaleTransition(
                scale: CurvedAnimation(parent: _tick, curve: Curves.elasticOut),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 48, color: Color(0xFF16A34A)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('ஆர்டர் பெறப்பட்டது! 🎉', textAlign: TextAlign.center, style: ts(21, w: w8)),
            const SizedBox(height: 4),
            Text('உறுதி செய்ததும் கடை பார்சல் செய்யும் — ஒவ்வொரு நிலையும் இங்கே தெரியும்', textAlign: TextAlign.center, style: ts(13, c: P.mu2, h: 1.45)),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: P.card2, border: Border.all(color: P.bd), borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                _row('ஆர்டர் எண்', widget.oNo),
                _row('தேதி', widget.date),
                if (widget.shopName.isNotEmpty) _row('கடை', widget.shopName),
                _row('பொருட்கள்', '₹${rupee(widget.sub)}'),
                if (widget.del > 0) _row('டெலிவரி கட்டணம்', '₹${rupee(widget.del)}'),
                _row('மொத்தம்', '₹${rupee(widget.tot)}'),
                _row('பணம்', '💵 பொருள் வந்ததும்'),
              ]),
            ),
            if (widget.ph.isNotEmpty) PushBlock(oid: widget.oid, ph: widget.ph, margin: const EdgeInsets.only(bottom: 14)),
            GreenButton('🛵 ஆர்டரைப் பின்தொடர', onTap: () => Navigator.pop(context, true)),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: P.bd), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () => Navigator.pop(context, false),
              child: Text('🛍️ தொடர்ந்து வாங்குங்கள்', style: ts(15, w: w8, c: P.mu2)),
            ),
          ]),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _cf,
              builder: (_, __) => LayoutBuilder(builder: (_, c) {
                if (_cf.value == 0 || _cf.value == 1) return const SizedBox.shrink();
                return Stack(children: [
                  for (final b in _bits)
                    Builder(builder: (_) {
                      final t = ((_cf.value * 2.2 - b[3]) / 1.8).clamp(0.0, 1.0).toDouble();
                      if (t <= 0 || t >= 1) return const SizedBox.shrink();
                      return Positioned(
                        left: c.maxWidth * b[0] / 100 + b[1] * t,
                        top: -10 + (c.maxHeight * .9) * Curves.easeIn.transform(t),
                        child: Opacity(
                          opacity: 1 - t,
                          child: Transform.rotate(
                            angle: b[2] * t * math.pi / 180,
                            child: Container(width: 8, height: 12, color: _cols[b[4].toInt() % _cols.length]),
                          ),
                        ),
                      );
                    }),
                ]);
              }),
            ),
          ),
        ),
      ]),
    );
  }
}

// ═══ ஒரு ஆர்டரைத் திற (வெற்றி sheet / முகப்பு strip / அறிவிப்பு) ═══
Future<void> openTrack(String oid) async {
  // மேலே திறந்திருக்கும் முழுத் திரைகளை (கணக்கு / அறிவிப்புகள் / கதைகள்) மூடு — ஆர்டர் மறைந்துவிடக்கூடாது
  Nav.root.currentState?.popUntil((r) => r.isFirst);
  final rows = await O.fetch(force: true);
  final list = O.build(rows);
  final o = list.where((x) => x.id == oid).first0;
  Nav.go('orders');
  if (o != null) Nav.push(OrderDetailScreen(id: oid), hl: 'orders');
}

// ═══ என் ஆர்டர்கள் ═══
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _tab = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    await O.fetch(force: force);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    return ListenableBuilder(
      listenable: O,
      builder: (_, __) {
        // HTML renderOrds: ஒவ்வொரு முறையும் புதிய fetch-லிருந்து; cloud தோல்வி → இந்த phone-ன் ஆர்டர்கள் மட்டும்
        final list = O.lastFail ? O.build(const []) : O.build();
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: P.card,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(tooltip: 'பின்செல்', icon: Icon(Icons.arrow_back, color: P.text), onPressed: () => Nav.back()),
            title: Text('ஆர்டர்கள்', style: ts(18, w: w8)),
            actions: [
              TextButton.icon(
                onPressed: () {
                  setState(() => _loading = true);
                  _load(force: true);
                },
                icon: Icon(Icons.refresh, size: 18, color: P.g2),
                label: Text('புதுப்பி', style: ts(13, w: w8, c: P.g2)),
              ),
            ],
          ),
          body: RefreshIndicator(
            color: P.g,
            onRefresh: () => _load(force: true),
            child: _loading && list.isEmpty
                ? ListView(children: const [StateBox('⏳', 'ஏற்றுகிறது...')])
                : list.isEmpty
                    ? ListView(children: [
                        const StateBox('📋', 'இன்னும் எந்த ஆர்டரும் இல்லை'),
                        Center(child: SizedBox(width: 220, child: GreenButton('🛍️ பொருட்களை பார்க்க', onTap: _browse))),
                      ])
                    : _list(list),
          ),
        );
      },
    );
  }

  // HTML: closeOrders(); if(homeOpen) closeHome(); → கீழே உள்ள கடைப் பக்கம்
  void _browse() {
    final s = AppState.I;
    final sh = s.shopById(s.activeShop);
    Nav.go('home');
    if (sh != null && !sh.hidden) Nav.openShop(sh.id);
  }

  Widget _list(List<OrderV> list) {
    final act = list.where(coActive).toList();
    final tab = _tab.isNotEmpty ? _tab : (act.isNotEmpty ? 'act' : 'all');
    final show = tab == 'act' ? act : list;
    final done = list.where((o) => !coActive(o)).toList();
    Widget tb(String k, String l, [int n = 0]) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _tab = k),
            // HTML .co-tabs button / .on
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(
                color: tab == k ? P.card : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                boxShadow: tab == k ? const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))] : null,
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(l, style: ts(14, w: w8, c: tab == k ? P.g2 : P.mu2)),
                if (n > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    height: 20,
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: P.g, borderRadius: BorderRadius.circular(10)),
                    child: Text('$n', style: ts(12, w: w8, c: Colors.white, h: 1)),
                  ),
                ],
              ]),
            ),
          ),
        );
    return ListView(padding: const EdgeInsets.only(bottom: 30), children: [
      if (O.lastFail)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Text('⚠️ Cloud இணைக்க முடியவில்லை — இந்த device-ன் வரலாறு காட்டப்படுகிறது', textAlign: TextAlign.center, style: ts(12, w: w7, c: P.or)),
        ),
      Container(
        margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: P.card2, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [tb('all', 'எல்லா ஆர்டர்கள்'), const SizedBox(width: 4), tb('act', 'நடப்பில்', act.length)]),
      ),
      if (tab == 'all' && done.isNotEmpty)
        // HTML .co-clr
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Row(children: [
            Expanded(child: Text('${list.length} ஆர்டர்கள்', style: ts(12.5, w: w7, c: P.mu2))),
            GestureDetector(
              onTap: () => _clearDone(done),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.center,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.delete_outline, size: 16, color: P.red),
                  const SizedBox(width: 5),
                  Text('முடிந்தவற்றை அழி (${done.length})', style: ts(13, w: w8, c: P.red)),
                ]),
              ),
            ),
          ]),
        ),
      if (show.isEmpty)
        StateBox('🛵', tab == 'act' ? 'நடப்பில் ஆர்டர் எதுவும் இல்லை' : 'ஆர்டர்கள் எதுவும் இல்லை', sub: 'புதிய ஆர்டர் செய்தால் இங்கே பின்தொடரலாம்')
      else
        ...show.map((o) => _OrderCard(o, onChanged: () => setState(() {}))),
    ]);
  }

  Future<void> _clearDone(List<OrderV> d) async {
    final ok = await confirmDialog('${d.length} முடிந்த ஆர்டர்கள் உங்கள் பட்டியலிலிருந்து நீக்கப்படும். நடப்பில் உள்ளவை அப்படியே இருக்கும். சரியா?');
    if (!ok) return;
    O.hide(d);
    toast('🗑️ முடிந்த ஆர்டர்கள் அழிக்கப்பட்டன');
  }
}

Future<bool> confirmDialog(String msg, {String yes = 'சரி', String no = 'வேண்டாம்', bool danger = false, String icon = ''}) async {
  final c = Nav.ctx;
  if (c == null) return false;
  final r = await showDialog<bool>(
    context: c,
    builder: (d) => AlertDialog(
      backgroundColor: P.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (icon.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(icon, style: const TextStyle(fontSize: 36))),
        Text(msg, textAlign: TextAlign.center, style: ts(15, w: w7, h: 1.5)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: Text(no, style: ts(14, w: w8, c: P.mu2))),
        TextButton(onPressed: () => Navigator.pop(d, true), child: Text(yes, style: ts(14, w: w8, c: danger ? const Color(0xFFDC2626) : P.g2))),
      ],
    ),
  );
  return r == true;
}

String coDate(OrderV o) {
  if (o.ts == 0) return o.date;
  final d = DateTime.fromMillisecondsSinceEpoch(o.ts), t = DateTime.now();
  final y = t.subtract(const Duration(days: 1));
  bool same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  final day = same(d, t) ? 'இன்று' : (same(d, y) ? 'நேற்று' : taDayMon(d));
  return '$day · ${tTime('${d.hour}:${d.minute}')}';
}

class _OrderCard extends StatelessWidget {
  final OrderV o;
  final VoidCallback onChanged;
  const _OrderCard(this.o, {required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final sh = s.shopById(o.shopId ?? '');
    final kt = s.kindOf(sh);
    final img = sh == null ? '' : (sh.logoImage.isNotEmpty ? sh.logoImage : sh.coverImage);
    final st = o.cloud ? (kCoSt[o.status] ?? [o.status, 'w', '🕒']) : ['இந்த phone-ல் மட்டும்', 'n', '📱'];
    final n = o.its.fold<int>(0, (a, i) => a + (i.q > 0 ? i.q : 1));
    final active = coActive(o);
    final stCol = {'w': const Color(0xFFB45309), 'b': const Color(0xFF0369A1), 'g': AppColors.primary, 'r': const Color(0xFFB91C1C), 'n': P.mu2}[st[1]]!;
    final stBg = {'w': const Color(0xFFFFF7E6), 'b': const Color(0xFFE0F2FE), 'g': const Color(0xFFDCFCE7), 'r': const Color(0xFFFEE2E2), 'n': P.card3}[st[1]]!;
    final revDone = s.revDoneMap();
    return GestureDetector(
      onTap: () => _open(),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: P.card, border: Border.all(color: P.bd), borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x0A101828), blurRadius: 10, offset: Offset(0, 2))]),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: P.gc, borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              child: img.isNotEmpty ? Img(img, emoji: kt?.e ?? '🛍️') : Center(child: Text(kt?.e ?? '🛍️', style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('#${o.no.replaceFirst(RegExp(r'^#'), '')}', style: ts(12, w: w7, c: P.mu)),
                Text(o.shop.isNotEmpty ? o.shop : (sh?.name ?? ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(15, w: w8)),
                Text.rich(TextSpan(style: ts(12.5, w: w6, c: P.mu2), children: [
                  if (n > 0) TextSpan(text: '$n ${n == 1 ? 'பொருள்' : 'பொருட்கள்'} · '),
                  TextSpan(text: '₹${rupee(o.tot)}', style: ts(12.5, w: w8, c: P.text)),
                ])),
                Text('${coDate(o)}${o.sched.isNotEmpty ? ' · 📅 ${o.sched}' : ''}', style: ts(12, c: P.mu)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: stBg, borderRadius: BorderRadius.circular(10)),
              child: Text('${st[2] == '✓' || st[2] == '✕' ? '${st[2]} ' : ''}${st[0]}', style: ts(12, w: w8, c: stCol)),
            ),
          ]),
          if (o.cloud && o.id != null && o.status == 'DELIVERED' && revDone[o.id] == null)
            GestureDetector(
              onTap: _open,
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('★★★★★', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 14)),
                  const SizedBox(width: 8),
                  Text('இந்த ஆர்டரை மதிப்பிடுங்கள்', style: ts(13, w: w8, c: const Color(0xFF92400E))),
                ]),
              ),
            ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 11), side: BorderSide(color: P.bd), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _open,
                child: Text('விவரங்கள்', style: ts(13.5, w: w8, c: P.mu2)),
              ),
            ),
            const SizedBox(width: 8),
            if (active)
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: P.g, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _open,
                  icon: const Icon(Icons.place, size: 16),
                  label: Text('பின்தொடர', style: ts(13.5, w: w8, c: Colors.white)),
                ),
              )
            else ...[
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: P.gc, foregroundColor: P.g2, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => reorderFrom(o),
                  icon: const Icon(Icons.repeat, size: 16),
                  label: Text('மீண்டும் வாங்க', style: ts(13.5, w: w8, c: P.g2)),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () => _delete(),
                icon: Icon(Icons.delete_outline, color: P.mu2),
                tooltip: 'இந்த ஆர்டரை நீக்கு',
              ),
            ],
          ]),
        ]),
      ),
    );
  }

  void _open() {
    if (o.id != null) {
      Nav.push(OrderDetailScreen(id: o.id!), hl: 'orders');
    } else {
      Nav.push(OrderDetailScreen(localNo: o.no), hl: 'orders');
    }
  }

  Future<void> _delete() async {
    if (coActive(o)) {
      toast('நடப்பில் உள்ள ஆர்டரை நீக்க முடியாது');
      return;
    }
    final ok = await confirmDialog('இந்த ஆர்டர் உங்கள் பட்டியலிலிருந்து நீக்கப்படும் (கடையின் பதிவில் இருக்கும்). சரியா?');
    if (!ok) return;
    O.hide([o]);
    toast('🗑️ ஆர்டர் நீக்கப்பட்டது');
    onChanged();
  }
}

// ═══ மீண்டும் வாங்க ═══
Future<void> reorderFrom(OrderV o) async {
  if (o.its.isEmpty) return;
  final plan = reorderPlan(o);
  if (plan.error.isNotEmpty) {
    toast(plan.error);
    return;
  }
  // HTML: முதலில் கடை மாற்றச் சோதனை, பிறகு மாற்று pack கேள்வி
  final first = (plan.matched.isNotEmpty ? plan.matched.first : plan.alts.first).p;
  if (!await CartOps.conflictOk(first)) return;
  var use = plan.matched;
  if (plan.alts.isNotEmpty) {
    final yes = await _askAlts(plan);
    use = yes ? [...plan.matched, ...plan.alts] : plan.matched;
  }
  if (use.isEmpty) {
    toast('⚠️ எதுவும் சேர்க்கப்படவில்லை');
    return;
  }
  final s = AppState.I;
  for (final l in use) {
    final have = s.qtyOf(l.p, l.pi);
    s.addLine(l.p, l.pi, qty: math.max(have, l.qty));
  }
  final notes = <String>[];
  if (plan.gone.isNotEmpty) notes.add('❌ இல்லை: ${plan.gone.take(2).join(', ')}${plan.gone.length > 2 ? ' +${plan.gone.length - 2}' : ''}');
  if (plan.priceUp > 0) notes.add('💰 ${plan.priceUp} பொருளின் விலை மாறியுள்ளது');
  toast('🔄 ${use.length} பொருட்கள் Cart-ல் சேர்க்கப்பட்டது${notes.isNotEmpty ? ' · ${notes.join(' · ')}' : ''}');
  Nav.go('cart');
}

Future<bool> _askAlts(ReoPlan plan) async {
  final c = Nav.ctx;
  if (c == null) return false;
  final r = await showModalBottomSheet<bool>(
    context: c,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (b) => Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(b).size.height * .8),
      decoration: BoxDecoration(color: P.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + MediaQuery.of(b).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(16)), alignment: Alignment.center, child: const Text('📦', style: TextStyle(fontSize: 26))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('சில pack-கள் இப்போது இல்லை', style: ts(17, w: w8)),
              Text('அதற்குப் பதில் கீழே உள்ளதை எடுக்கவா?', style: ts(12.5, c: P.mu2)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Flexible(
          child: ListView(shrinkWrap: true, children: [
            for (final a in plan.alts)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: P.bd))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.nm, style: ts(14, w: w8)),
                  Text.rich(TextSpan(style: ts(13, c: P.mu2), children: [
                    TextSpan(text: a.was.isNotEmpty ? a.was : 'பழைய pack', style: const TextStyle(decoration: TextDecoration.lineThrough)),
                    const TextSpan(text: ' இல்லை → '),
                    TextSpan(text: '${a.now} · ₹${rupee(a.price)}', style: ts(13, w: w8, c: AppColors.primaryDark)),
                    TextSpan(text: ' × ${a.qty}'),
                  ])),
                ]),
              ),
          ]),
        ),
        if (plan.gone.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('❌ கிடைக்காதவை: ${plan.gone.join(', ')}', style: ts(12.5, c: const Color(0xFFB91C1C)))),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: P.bd), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () => Navigator.pop(b, false),
              child: Text('வேண்டாம்', style: ts(15, w: w8, c: P.mu2)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: GreenButton('✓ இவற்றையும் சேர்', height: 50, onTap: () => Navigator.pop(b, true))),
        ]),
      ]),
    ),
  );
  return r == true;
}

// ═══ ஆர்டர் விவரம் / பின்தொடர்தல் ═══
class OrderDetailScreen extends StatefulWidget {
  final String? id;
  final String? localNo;
  const OrderDetailScreen({super.key, this.id, this.localNo});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> with WidgetsBindingObserver {
  Timer? _t;
  bool _cancelBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _t = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _t?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.resumed) _tick();
  }

  // 15 வினாடிக்கு ஒருமுறை (app முன்னால் இருக்கும்போது மட்டும்)
  Future<void> _tick() async {
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    final o = _find();
    if (o == null || !coActive(o)) return;
    await O.fetch(force: true);
  }

  OrderV? _find() {
    final l = O.build();
    if (widget.id != null) return l.where((x) => x.id == widget.id).first0;
    return l.where((x) => x.no == widget.localNo).first0;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    return ListenableBuilder(
      listenable: O,
      builder: (_, __) {
        final o = _find();
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: P.card,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(tooltip: 'பின்செல்', icon: Icon(Icons.arrow_back, color: P.text), onPressed: () => Navigator.of(context).maybePop()),
            title: Text('ஆர்டர் விவரங்கள்', style: ts(18, w: w8)),
          ),
          body: o == null ? const StateBox('🧾', 'இந்த ஆர்டர் கிடைக்கவில்லை') : RefreshIndicator(color: P.g, onRefresh: () => O.fetch(force: true), child: _body(o)),
        );
      },
    );
  }

  Widget _card(Widget child, {Color? bg, EdgeInsets? pad}) => Container(
        margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        padding: pad ?? const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg ?? P.card, border: Border.all(color: P.bd), borderRadius: BorderRadius.circular(18)),
        child: child,
      );

  String _tm(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    return d == null ? '' : hm12(d);
  }

  Widget _body(OrderV o) {
    final s = AppState.I;
    final shop = s.shopById(o.shopId ?? '');
    final st = o.status, active = coActive(o);
    const hh = {
      'ORDER_RECEIVED': ['🧾', 'ஆர்டர் பெறப்பட்டது', 'Crispy உங்கள் ஆர்டரை உறுதி செய்கிறது'],
      'READY_FOR_PICKUP': ['🛍️', 'பார்சல் ரெடி!', 'Delivery நபர் கடையிலிருந்து எடுக்க வருகிறார்'],
      'DELIVERY_ASSIGNED': ['🛍️', 'பார்சல் ரெடி!', 'Delivery நபர் கடையிலிருந்து எடுக்க வருகிறார்'],
      'DELIVERED': ['🎉', 'டெலிவரி முடிந்தது', 'Crispy-ஐத் தேர்ந்தெடுத்ததற்கு நன்றி!'],
      'CANCELLED': ['❌', 'ஆர்டர் ரத்து செய்யப்பட்டது', 'கேள்விகள் இருந்தால் கீழே உதவி பட்டனைத் தட்டுங்கள்'],
    };
    List<String>? h = hh[st];
    if (st == 'SHOP_ACCEPTED' || st == 'PREPARING') h = ['📦', '${o.shop.isNotEmpty ? o.shop : 'கடை'} பார்சல் செய்கிறது', 'உங்கள் பொருட்கள் தயாராகின்றன'];
    if (st == 'OUT_FOR_DELIVERY') h = ['🛵', 'உங்களை நோக்கி வருகிறது!', '${o.dpName.isNotEmpty ? '${o.dpName} ' : ''}உங்கள் ஆர்டரைக் கொண்டு வருகிறார்'];
    var eta = '';
    if (active && o.sched.isNotEmpty) {
      eta = '📅 ${o.sched} அன்று வரும்';
    } else if (active && shop != null && jz(shop.m['delivery_max']) > 0 && o.t['c'] != null) {
      final c0 = DateTime.tryParse(o.t['c']!)?.toLocal();
      if (c0 != null) {
        final by = c0.add(Duration(minutes: jz(shop.m['delivery_max']).toInt()));
        eta = by.isAfter(DateTime.now()) ? '⏱ ${hm12(by)}-க்குள் வந்துவிடும்' : '⏱ சிறிது நேரத்தில் வந்துவிடும்';
      }
    }
    // HTML .tk-hero (160deg): இயல்பு --hdr→--hdr2, .done #166534→#22a35a, .bad #991b1b→#dc2626
    final bad = st == 'CANCELLED';
    final heroBg = bad
        ? const [Color(0xFF991B1B), Color(0xFFDC2626)]
        : st == 'DELIVERED'
            ? const [AppColors.primaryDark, Color(0xFF22A35A)]
            : [P.hdr, P.hdr2];
    final kids = <Widget>[];
    kids.add(Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: heroBg, begin: const Alignment(-.342, -.94), end: const Alignment(.342, .94)),
        borderRadius: BorderRadius.circular(22),
        boxShadow: bad ? null : const [BoxShadow(color: Color(0x40166534), blurRadius: 22, offset: Offset(0, 8))],
      ),
      child: Column(children: [
        if (o.cloud && h != null) ...[
          _LiveIcon(h[0], live: active),
          const SizedBox(height: 10),
          Text(h[1], textAlign: TextAlign.center, style: ts(19, w: w8, c: Colors.white)),
          const SizedBox(height: 4),
          Text(h[2], textAlign: TextAlign.center, style: ts(13, c: const Color(0xE6FFFFFF))),
          if (eta.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0x2EFFFFFF), borderRadius: BorderRadius.circular(20)),
              child: Text(eta, style: ts(13, w: w8, c: Colors.white)),
            ),
          const SizedBox(height: 10),
          Text('ஆர்டர் ${o.no} · ${o.date}', style: ts(12, c: const Color(0xCCFFFFFF))),
          if (o.sched.isNotEmpty && !active) Padding(padding: const EdgeInsets.only(top: 6), child: Text('📅 முன்பதிவு: ${o.sched}', style: ts(12.5, w: w8, c: Colors.white))),
        ] else ...[
          const Text('🧾', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text('ஆர்டர் ${o.no}', style: ts(19, w: w8, c: Colors.white)),
          const SizedBox(height: 4),
          Text(
            o.oid != null
                ? '📴 இணைய இணைப்பு இல்லாததால் இப்போதைய நிலையைக் காட்ட முடியவில்லை. இணைப்பு வந்ததும் தானாகத் தெரியும்.'
                : 'இந்த ஆர்டர் WhatsApp வழியாக அனுப்பப்பட்டது. நிலையை கடையிடம் கேட்டு அறியலாம்.',
            textAlign: TextAlign.center,
            style: ts(13, c: const Color(0xE6FFFFFF), h: 1.45),
          ),
          const SizedBox(height: 8),
          Text(o.date, style: ts(12, c: const Color(0xCCFFFFFF))),
        ],
      ]),
    ));
    if (st == 'CANCELLED' && o.cr.isNotEmpty) {
      kids.add(_card(Text.rich(TextSpan(style: ts(13.5, c: const Color(0xFF991B1B)), children: [
        const TextSpan(text: '❌ '),
        TextSpan(text: 'ரத்து காரணம்: ', style: ts(13.5, w: w8, c: const Color(0xFF991B1B))),
        TextSpan(text: o.cr),
      ])), bg: const Color(0xFFFEF2F2)));
    }
    if (o.cloud && o.id != null && st == 'DELIVERED') kids.add(RevAsk(o));
    if (o.cloud && st != 'CANCELLED') {
      const rankOf = {'ORDER_RECEIVED': 0, 'SHOP_ACCEPTED': 1, 'PREPARING': 1, 'READY_FOR_PICKUP': 2, 'DELIVERY_ASSIGNED': 2, 'OUT_FOR_DELIVERY': 3, 'DELIVERED': 4};
      final rank = rankOf[st] ?? 0;
      final steps = [
        ['ஆர்டர் பெறப்பட்டது', o.t['c']],
        ['உறுதி செய்யப்பட்டது', o.t['a']],
        ['பார்சல் ரெடி', o.t['r']],
        ['உங்களை நோக்கி புறப்பட்டது', o.t['p']],
        ['டெலிவரி முடிந்தது', o.t['d']],
      ];
      kids.add(_card(Column(children: [
        for (var i = 0; i < steps.length; i++)
          _TlStep(
            label: steps[i][0]!,
            time: i <= rank && steps[i][1] != null ? _tm(steps[i][1]) : '',
            done: i <= rank,
            cur: i == rank && active,
            last: i == steps.length - 1,
          ),
      ])));
    }
    if (active && o.otp.isNotEmpty) {
      kids.add(_card(
        Column(children: [
          Text('🔐 டெலிவரி OTP', style: ts(13, w: w8, c: const Color(0xFF92400E))),
          const SizedBox(height: 6),
          Text(o.otp.split('').join(' '), style: pop(32, c: const Color(0xFF78350F))),
          const SizedBox(height: 8),
          Text('பார்சலை கையில் வாங்கி, பணம் கொடுத்த பிறகு மட்டும் delivery நண்பரிடம் இந்த எண்ணைச் சொல்லுங்கள். முன்பே, போனில் யாரிடமும் சொல்ல வேண்டாம்.',
              textAlign: TextAlign.center, style: ts(12.5, c: const Color(0xFF92400E), h: 1.5)),
        ]),
        bg: const Color(0xFFFFFBEB),
      ));
    }
    final dph = o.dpPhone.replaceAll(RegExp(r'\D'), '');
    final dph10 = dph.length > 10 ? dph.substring(dph.length - 10) : dph;
    if (o.dpName.isNotEmpty && active) {
      kids.add(_card(Row(children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: P.gc, shape: BoxShape.circle), alignment: Alignment.center, child: const Text('🛵', style: TextStyle(fontSize: 24))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o.dpName, style: ts(15, w: w8)),
            Text('உங்கள் delivery நண்பர்', style: ts(12, c: P.mu)),
          ]),
        ),
        if (dph10.isNotEmpty)
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: P.g, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => openUrl('tel:+91$dph10'),
            child: Text('📞 அழை', style: ts(13.5, w: w8, c: Colors.white)),
          ),
      ])));
    }
    // HTML: delivery நபருக்குப் பிறகு, பில்லுக்கு முன் 🔔 (margin 10 14 0)
    if (o.cloud && active && o.id != null && o.ph.isNotEmpty) kids.add(PushBlock(oid: o.id!, ph: o.ph, margin: const EdgeInsets.fromLTRB(14, 10, 14, 0)));
    // பில்
    final sub = o.sub ?? o.its.fold<double>(0, (a, i) => a + i.t);
    kids.add(_card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('🛍️ ${o.shop} · ${o.its.length} பொருட்கள்', style: ts(14, w: w8)),
      const SizedBox(height: 8),
      for (final i in o.its)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${i.n}${i.w.isNotEmpty ? ' · ${i.w}' : ''} × ${i.q}',
                    style: ts(13.5, w: w6, c: i.na ? P.mu : P.text, deco: i.na ? TextDecoration.lineThrough : null)),
                if (i.na) Text('கடையில் இல்லை', style: ts(12, w: w8, c: const Color(0xFFB91C1C))),
              ]),
            ),
            Text('₹${rupee(i.t)}', style: ts(13.5, w: w7, c: i.na ? P.mu : P.text, deco: i.na ? TextDecoration.lineThrough : null)),
          ]),
        ),
      if (o.its.any((i) => i.na))
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(10)),
          child: Text('கடையில் இல்லாத பொருட்கள் உங்கள் தொகையிலிருந்து கழிக்கப்பட்டன — கீழே உள்ளதுதான் புதிய தொகை', style: ts(12, w: w7, c: const Color(0xFF9A5B00))),
        ),
      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(color: P.bd, height: 1)),
      _bl('பொருட்கள்', '₹${rupee(sub)}'),
      _bl('டெலிவரி கட்டணம்', o.del > 0 ? '₹${rupee(o.del)}' : 'இலவசம்', green: o.del <= 0),
      const SizedBox(height: 4),
      Row(children: [
        Text('${st == 'DELIVERED' ? 'செலுத்தியது' : 'செலுத்த வேண்டியது'} · ${o.pm == 'upi' ? 'UPI' : 'கையில் பணம்'}', style: ts(14, w: w8)),
        const Spacer(),
        Text('₹${rupee(o.tot)}', style: pop(17)),
      ]),
    ])));
    // முகவரி
    kids.add(_card(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('🏠', style: TextStyle(fontSize: 22)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${o.nm}${o.ph.isNotEmpty ? ' · ${o.ph}' : ''}', style: ts(14, w: w8)),
          Text(o.ad, style: ts(12.5, c: P.mu2, h: 1.45)),
          if (o.nt.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('🗒️ ${o.nt}', style: ts(12.5, c: P.mu2))),
        ]),
      ),
    ])));
    // செயல்கள்
    final wn = js(s.waNum).replaceAll(RegExp(r'\D'), '');
    final wnFull = wn.length == 10 ? '91$wn' : wn;
    kids.add(Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Row(children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: () => openUrl('https://wa.me/$wnFull?text=${Uri.encodeComponent('ஆர்டர் எண்: ${o.no} பற்றி')}'),
            child: Text('💬 உதவி', style: ts(14.5, w: w8, c: Colors.white)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: P.g, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: () => reorderFrom(o),
            child: Text('🔄 மீண்டும் வாங்க', style: ts(14.5, w: w8, c: P.g2)),
          ),
        ),
      ]),
    ));
    if (o.cloud && o.id != null && kCustCancel.contains(st)) {
      kids.add(Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: TextButton(
          onPressed: _cancelBusy ? null : () => _cancel(o),
          child: Text(_cancelBusy ? '⏳ ரத்து செய்யப்படுகிறது...' : 'ஆர்டரை ரத்து செய்ய', style: ts(14, w: w8, c: const Color(0xFFDC2626), deco: TextDecoration.underline)),
        ),
      ));
    }
    kids.add(const SizedBox(height: 40));
    return ListView(children: kids);
  }

  Widget _bl(String l, String v, {bool green = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Text(l, style: ts(13.5, c: green ? P.g2 : P.mu2)), const Spacer(), Text(v, style: ts(13.5, w: w8, c: green ? P.g2 : P.text))]),
      );

  // ORDER_RECEIVED / SHOP_ACCEPTED நிலையில் மட்டும் (customer_cancel_order சரிபார்க்கும்)
  Future<void> _cancel(OrderV o) async {
    final ok = await confirmDialog('ஆர்டர் ${o.no}-ஐ ரத்து செய்யவா?', yes: 'ஆம், ரத்து செய்', danger: true, icon: '❌');
    if (!ok || !mounted) return;
    setState(() => _cancelBusy = true);
    final res = await Orders.cancel(o);
    if (!mounted) return;
    setState(() => _cancelBusy = false);
    if (res['ok'] == true) {
      toast('✅ ஆர்டர் ரத்து செய்யப்பட்டது');
      await O.fetch(force: true);
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    if (js(res['msg']).isNotEmpty) toast('ℹ️ ${js(res['msg'])}');
    final wn = js(AppState.I.waNum).replaceAll(RegExp(r'\D'), '');
    final full = wn.length == 10 ? '91$wn' : wn;
    await openUrl('https://wa.me/$full?text=${Uri.encodeComponent('ஆர்டர் எண்: ${o.no} — இதை ரத்து செய்ய விரும்புகிறேன்.')}');
    toast('ℹ️ ரத்து கோரிக்கையை Crispy-க்கு WhatsApp-ல் அனுப்புங்கள்');
  }
}

class _LiveIcon extends StatefulWidget {
  final String e;
  final bool live;
  const _LiveIcon(this.e, {required this.live});
  @override
  State<_LiveIcon> createState() => _LiveIconState();
}

class _LiveIconState extends State<_LiveIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  @override
  void initState() {
    super.initState();
    if (widget.live && !reducedMotion) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 90,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          if (widget.live)
            Container(
              width: 64 + 26 * _c.value,
              height: 64 + 26 * _c.value,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .25 * (1 - _c.value))),
            ),
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(widget.e, style: const TextStyle(fontSize: 32)),
          ),
        ]),
      ),
    );
  }
}

class _TlStep extends StatelessWidget {
  final String label, time;
  final bool done, cur, last;
  const _TlStep({required this.label, required this.time, required this.done, required this.cur, required this.last});
  @override
  Widget build(BuildContext context) {
    final col = done ? P.g : P.bd;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 26,
          child: Column(children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: done && !cur ? P.g : P.card,
                border: Border.all(color: col, width: cur ? 4 : 2),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: done && !cur ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
            ),
            if (!last) Expanded(child: Container(width: 2.5, color: col)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 16, top: 1),
            child: Text(label, style: ts(14, w: cur ? w9 : (done ? w8 : w6), c: done ? P.text : P.mu)),
          ),
        ),
        Text(time, style: ts(12, w: w7, c: P.mu)),
      ]),
    );
  }
}

// ═══ முகப்பு: நடப்பு ஆர்டர் strip (கடந்த 36 மணி நேரம்) ═══
class ActiveOrderStrip extends StatefulWidget {
  const ActiveOrderStrip({super.key});
  @override
  State<ActiveOrderStrip> createState() => _ActiveOrderStripState();
}

class _ActiveOrderStripState extends State<ActiveOrderStrip> {
  @override
  void initState() {
    super.initState();
    final recent = AppState.I.ordLocal().where((o) => js(o['oid']).isNotEmpty && DateTime.now().millisecondsSinceEpoch - jz(o['ts']) < 36 * 3600 * 1000);
    if (recent.isNotEmpty) O.fetch();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: O,
      builder: (_, __) {
        final recent = AppState.I.ordLocal().where((o) => js(o['oid']).isNotEmpty && DateTime.now().millisecondsSinceEpoch - jz(o['ts']) < 36 * 3600 * 1000);
        if (recent.isEmpty || O.cache == null) return const SizedBox.shrink();
        final a = O.build().where(coActive).toList();
        if (a.isEmpty) return const SizedBox.shrink();
        final o = a.first;
        final st = kCoSt[o.status] ?? ['நடப்பில்', 'w', '🕒'];
        return GestureDetector(
          onTap: () => Nav.go('orders'),
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)]),
              border: Border.all(color: const Color(0xFFFDBA74), width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Text(st[2], style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('உங்கள் ஆர்டர்${a.length > 1 ? ' (${a.length})' : ''} · ${o.shop}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, w: w7, c: const Color(0xFF9A3412))),
                  Text(st[0], style: ts(15, w: w8, c: const Color(0xFF7C2D12))),
                ]),
              ),
              if (o.otp.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Column(children: [
                    Text('OTP', style: ts(12, w: w8, c: const Color(0xFF9A3412))),
                    Text(o.otp, style: pop(16, c: const Color(0xFF7C2D12))),
                  ]),
                )
              else
                Text('பார்க்க ›', style: ts(13, w: w8, c: const Color(0xFF9A3412))),
            ]),
          ),
        );
      },
    );
  }
}


// ═══ ⭐ இந்த ஆர்டர் எப்படி இருந்தது? (ஒருமுறை; பின்னர் மாற்றலாம்) ═══
const List<String> kRevLbl = ['', 'மோசம் 😞', 'சுமார் 😐', 'பரவாயில்லை 🙂', 'நல்லது 😊', 'மிக அருமை 🤩'];

class RevAsk extends StatefulWidget {
  final OrderV o;
  const RevAsk(this.o, {super.key});
  @override
  State<RevAsk> createState() => _RevAskState();
}

class _RevAskState extends State<RevAsk> {
  bool _edit = false, _busy = false;
  int _pick = 0;
  final _txt = TextEditingController();

  @override
  void dispose() {
    _txt.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_pick == 0) return;
    setState(() => _busy = true);
    final o = widget.o;
    final r = await Api.rpc('submit_review', {'p_order_id': o.id, 'p_phone': o.ph, 'p_rating': _pick, 'p_comment': _txt.text});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.status == 0) {
      toast('📴 Network பிரச்சனை — மீண்டும் முயலுங்கள்');
      return;
    }
    final d = r.data is Map ? r.data as Map : null;
    if (d == null || d['ok'] != true) {
      toast('⚠️ ${d != null && js(d['msg']).isNotEmpty ? js(d['msg']) : (r.status == 404 ? 'கருத்து வசதி இன்னும் தயாராகவில்லை' : 'அனுப்ப முடியவில்லை — மீண்டும் முயலுங்கள்')}');
      return;
    }
    final m = AppState.I.revDoneMap();
    m[o.id!] = _pick;
    Store.setJson(K.revDone, m);
    setState(() => _edit = false);
    toast('⭐ நன்றி! உங்கள் கருத்து சேர்க்கப்பட்டது');
    AppState.I.loadReviews();
  }

  @override
  Widget build(BuildContext context) {
    final done = AppState.I.revDoneMap()[widget.o.id];
    final box = BoxDecoration(color: const Color(0xFFFFFBEB), border: Border.all(color: const Color(0xFFFDE68A)), borderRadius: BorderRadius.circular(18));
    if (done != null && !_edit) {
      final n = jz(done).toInt();
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        padding: const EdgeInsets.all(14),
        decoration: box,
        child: Row(children: [
          Text(List.generate(5, (i) => i < n ? '★' : '☆').join(), style: const TextStyle(fontSize: 18, color: Color(0xFFF59E0B))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('கருத்துக்கு நன்றி!', style: ts(14, w: w8, c: const Color(0xFF78350F))),
              Text('மற்ற வாடிக்கையாளர்களுக்கு உதவும்', style: ts(12, c: const Color(0xFF92400E))),
            ]),
          ),
          TextButton(
            onPressed: () => setState(() {
              _edit = true;
              _pick = n;
            }),
            child: Text('மாற்று', style: ts(13, w: w8, c: const Color(0xFF92400E))),
          ),
        ]),
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.all(16),
      decoration: box,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('இந்த ஆர்டர் எப்படி இருந்தது?', textAlign: TextAlign.center, style: ts(16, w: w8, c: const Color(0xFF78350F))),
        Text('${widget.o.shop.isNotEmpty ? widget.o.shop : 'கடை'} பற்றி உங்கள் மதிப்பீடு', textAlign: TextAlign.center, style: ts(12.5, c: const Color(0xFF92400E))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 1; i <= 5; i++)
            GestureDetector(
              onTap: () {
                Sfx.click();
                setState(() => _pick = i);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('★', style: TextStyle(fontSize: 38, color: i <= _pick ? const Color(0xFFF59E0B) : const Color(0xFFE5E7EB))),
              ),
            ),
        ]),
        Text(_pick > 0 ? kRevLbl[_pick] : 'நட்சத்திரத்தைத் தொடுங்கள்', textAlign: TextAlign.center, style: ts(13.5, w: w8, c: const Color(0xFF92400E))),
        const SizedBox(height: 10),
        TextField(
          controller: _txt,
          maxLength: 300,
          maxLines: 2,
          style: ts(14),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'ஒரு வரி எழுதுங்கள் (விருப்பம்) — உதா: பொருட்கள் புதுசா இருந்தது',
            hintStyle: ts(13, c: P.mu),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFDE68A))),
          ),
        ),
        const SizedBox(height: 10),
        GreenButton(_busy ? '⏳ அனுப்புகிறது...' : 'கருத்தை அனுப்பு', height: 48, onTap: _pick > 0 && !_busy ? _send : null),
      ]),
    );
  }
}
