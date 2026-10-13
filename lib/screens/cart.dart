// சிட்டை — கூடை = Checkout: பொருட்கள், முகவரி, டெலிவரி நேரம் (இப்போதே / முன்பதிவு), பில், ஆர்டர் (place_order)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../nav.dart';
import '../orders.dart';
import '../state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';
import '../push.dart';
import 'account.dart';
import 'location.dart';
import 'orders.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static String ckNote = '';
  static String ckMode = 'now';
  static int ckDay = 0;
  static SchSlot? ckWhen;
  static String ckWhenLabel = '';
  static String? ckCid; // ஒரு checkout முயற்சிக்கு ஒரு id: retry செய்தாலும் இரட்டை ஆர்டர் வராது
  bool _busy = false;
  late final TextEditingController _note = TextEditingController(text: ckNote);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final its = s.cart.values.toList();
    final cnt = s.cartCount;
    return Scaffold(
      backgroundColor: P.bg,
      appBar: AppBar(
        backgroundColor: P.card,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: IconButton(tooltip: 'பின்செல்', icon: Icon(Icons.arrow_back, color: P.text), onPressed: () => Nav.back()),
        titleSpacing: 0,
        title: Row(children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: P.gc, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.shopping_cart_outlined, color: P.g2, size: 21),
            ),
            if (cnt > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: P.g, borderRadius: BorderRadius.circular(10), border: Border.all(color: P.card, width: 1.5)),
                  child: Text('$cnt', style: ts(12, w: w8, c: Colors.white)),
                ),
              ),
          ]),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('என் கூடை', style: ts(17, w: w8)),
            Text(its.isEmpty ? 'காலியாக உள்ளது' : '$cnt ${cnt == 1 ? 'பொருள்' : 'பொருட்கள்'} • ₹${rupee(s.cartAmount)}', style: ts(12, w: w6, c: P.mu)),
          ]),
        ]),
      ),
      body: its.isEmpty ? _empty() : _body(s, its),
      bottomNavigationBar: its.isEmpty ? null : _bar(s),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🛒', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 10),
            Text('உங்கள் கூடை காலியாக உள்ளது', style: ts(17, w: w8)),
            const SizedBox(height: 6),
            Text('பிடித்த பொருட்களைச் சேர்த்து தொடங்குங்கள்', style: ts(13, c: P.mu)),
            const SizedBox(height: 20),
            SizedBox(width: 220, child: GreenButton('பொருட்களைப் பார்க்க', onTap: Nav.leave)),
          ]),
        ),
      );

  Shop? _shop(AppState s) => s.shopById(s.cartShopId ?? '');

  Widget _card({required Widget child, EdgeInsets? pad}) => Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        padding: pad ?? const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: P.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: P.bd),
          boxShadow: const [BoxShadow(color: Color(0x0A101828), blurRadius: 10, offset: Offset(0, 2))],
        ),
        child: child,
      );

  Widget _warn(String t, {Color bg = const Color(0xFFFEE2E2), Color fg = const Color(0xFFB91C1C)}) => Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Text(t, style: ts(13, w: w8, c: fg, h: 1.45)),
      );

  Widget _body(AppState s, List<CartLine> its) {
    final sub = s.cartAmount;
    final sh = _shop(s);
    final t = calcOrderTotals(sh, sub);
    final cnt = s.cartCount;
    double saved = 0;
    for (final i in its) {
      final o = i.pack.offer;
      if (o != null) saved += (o.mrp - o.price) * i.qty;
    }
    saved = round2(saved);
    final closed = sh != null && !sh.acceptingOrders;
    final closedNow = sh != null && !closed && !sh.isOpenNow;
    if (closedNow && ckMode == 'now') ckMode = 'later';
    final eta = sh != null && sh.etaKnown ? '${sh.etaText} நிமிடம்' : '';
    final minO = sh != null ? jz(sh.m['min_order']) : 0.0;
    final below = minO > 0 && sub < minO;

    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      // கடை
      GestureDetector(
        onTap: () {
          if (sh != null) Nav.openShop(sh.id);
        },
        child: _card(
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: P.gc, borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: sh != null && sh.logoImage.isNotEmpty ? Img(sh.logoImage, emoji: '🏪') : Center(child: Text(sh?.logoEmoji('🏪') ?? '🏪', style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sh?.name ?? '', style: ts(15.5, w: w8)),
                Text('${eta.isNotEmpty ? '🛵 $eta · ' : ''}$cnt ${cnt == 1 ? 'பொருள்' : 'பொருட்கள்'}', style: ts(12.5, w: w6, c: P.mu)),
              ]),
            ),
            Icon(Icons.chevron_right, color: P.mu),
          ]),
        ),
      ),
      if (closed) _warn('⛔ ${sh!.name} தற்போது ஆர்டர் ஏற்கவில்லை'),
      if (closedNow) _warn('🕐 ${sh!.name} இப்போது மூடியுள்ளது — கீழே டெலிவரி நேரத்தைத் தேர்ந்தெடுத்து முன்பதிவு செய்யலாம்', bg: const Color(0xFFFFF7E6), fg: const Color(0xFF9A5B00)),
      _freeBar(sh, sub),
      // பொருட்கள்
      _card(
        pad: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: Column(children: [
          Row(children: [
            Icon(Icons.shopping_bag_outlined, size: 19, color: P.g2),
            const SizedBox(width: 6),
            Expanded(child: Text('$cnt ${cnt == 1 ? 'பொருள்' : 'பொருட்கள்'}', style: ts(14, w: w8))),
            TextButton(onPressed: Nav.leave, child: Text('+ மேலும் சேர்', style: ts(13, w: w8, c: P.g2))),
          ]),
          for (final i in its) _item(i),
          if (saved > 0)
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: P.gc, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(Icons.local_offer_outlined, size: 15, color: P.g2),
                const SizedBox(width: 6),
                Expanded(child: Text.rich(TextSpan(style: ts(13, w: w7, c: P.g2), children: [const TextSpan(text: 'இந்த ஆர்டரில் '), TextSpan(text: '₹${rupee(saved)}', style: ts(13, w: w9, c: P.g2)), const TextSpan(text: ' சேமிக்கிறீர்கள்')]))),
              ]),
            ),
        ]),
      ),
      _addrCard(s, sh),
      if (!closed && sh != null) _schCard(sh, closedNow, eta),
      // குறிப்பு
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.sticky_note_2_outlined, size: 19, color: P.g2),
            const SizedBox(width: 6),
            Text('கடைக்கு குறிப்பு ', style: ts(14, w: w8)),
            Text('(விருப்பம்)', style: ts(12, c: P.mu)),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLength: 300,
            onChanged: (v) => ckNote = v,
            style: ts(14.5),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'உதா: மாலை 6 மணிக்கு மேல் கொடுங்கள்',
              hintStyle: ts(14, c: P.mu),
              filled: true,
              fillColor: P.card2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: P.inputBd)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: P.inputBd)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: P.g, width: focusW())),
            ),
          ),
        ]),
      ),
      // பணம்
      _card(
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: P.gc, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.payments_outlined, color: P.g2)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('பொருள் வந்ததும் பணம்', style: ts(14.5, w: w8)),
              Text('கையில் பணம் கொடுத்தால் போதும்', style: ts(12.5, c: P.mu)),
            ]),
          ),
          Container(width: 26, height: 26, decoration: BoxDecoration(color: P.g, shape: BoxShape.circle), child: const Icon(Icons.check, size: 17, color: Colors.white)),
        ]),
      ),
      // ரசீது வடிவ பில்
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: ClipPath(
          clipper: _ZigZag(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
            color: P.card,
            child: Column(children: [
              // HTML .cx-bh
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                LineIcon(kIcReceipt, size: 18, stroke: 2.1, color: P.text),
                const SizedBox(width: 5),
                Text('சிட்டை', style: ts(16, w: w8)),
                const Spacer(),
                Text('பில் விவரம்', style: ts(12, w: w7, c: P.mu)),
              ]),
              Padding(padding: const EdgeInsets.only(top: 9, bottom: 6), child: _dash()),
              _billRow(kCxCart, 'பொருட்களின் விலை', '₹${rupee(sub + saved)}'),
              if (saved > 0) _billRow(kCxTag, 'தள்ளுபடி', '− ₹${rupee(saved)}', green: true),
              _billRow(kCxTruck, 'டெலிவரி கட்டணம்', t.del > 0 ? '₹${rupee(t.del)}' : 'இலவசம்', green: t.del <= 0),
              Padding(padding: const EdgeInsets.only(top: 8, bottom: 12), child: _dash()),
              // HTML .cx-bt: ₹ வட்டம் + மொத்தம் (19px w800)
              Row(children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: P.g, shape: BoxShape.circle),
                  child: Text('₹', style: ts(13, c: Colors.white, h: 1)),
                ),
                const SizedBox(width: 9),
                Text('மொத்தம்', style: ts(19, w: w8)),
                const Spacer(),
                Text('₹${rupee(t.tot)}', style: ts(19, w: w8, c: AppState.I.dark ? P.text : AppColors.brand)),
              ]),
            ]),
          ),
        ),
      ),
      if (below) _warn('🧾 குறைந்தபட்ச ஆர்டர் ₹${rupee(minO)} — இன்னும் ₹${rupee(minO - sub)} பொருட்கள் சேர்க்கவும்'),
      Padding(
        padding: const EdgeInsets.all(14),
        child: Text.rich(
          TextSpan(style: ts(12, c: P.mu, h: 1.5), children: [
            const TextSpan(text: 'ஆர்டர் செய்வதன் மூலம் '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: GestureDetector(
                onTap: () => pushFull(const InfoScreen(page: 'terms')),
                child: Text('விதிமுறைகளை', style: ts(12, w: w7, c: AppState.I.dark ? P.g2 : AppColors.primaryDark, h: 1.5)),
              ),
            ),
            const TextSpan(text: ' ஏற்கிறீர்கள்'),
          ]),
          textAlign: TextAlign.center,
        ),
      ),
    ]);
  }

  Widget _dash() => LayoutBuilder(
        builder: (_, c) => Row(
          children: List.generate((c.maxWidth / 8).floor(), (_) => Container(width: 4, height: 2, margin: const EdgeInsets.only(right: 4), color: P.bd)),
        ),
      );

  // HTML .cx-br: icon + பெயர் (mu2 w600) · தொகை (w800; g = பச்சை)
  Widget _billRow(String ic, String l, String v, {bool green = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          LineIcon(ic, size: 20, stroke: 2.1, color: P.g2),
          const SizedBox(width: 9),
          Text(l, style: ts(14, w: w6, c: P.mu2)),
          const Spacer(),
          Text(v, style: ts(14, w: w8, c: green ? (AppState.I.dark ? P.g2 : const Color(0xFF16A34A)) : P.text)),
        ]),
      );

  // இலவச டெலிவரி progress (3 படி)
  Widget _freeBar(Shop? sh, double sub) {
    if (sh == null || !sh.deliveryAvailable) return const SizedBox.shrink();
    final fa = jz(sh.m['free_delivery_above']), ch = jz(sh.m['delivery_charge']);
    if (!(ch > 0 && fa > 0)) return const SizedBox.shrink();
    final ra = jz(sh.m['reduced_above']), c2 = jz(sh.m['delivery_charge2']);
    final pct = (sub / fa).clamp(0.0, 1.0).toDouble();
    if (sub >= fa) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(color: P.gc, border: Border.all(color: P.bd), borderRadius: BorderRadius.circular(14)),
        child: Text('🎉 இந்த ஆர்டருக்கு டெலிவரி இலவசம்!', style: ts(13, w: w8, c: P.g2)),
      );
    }
    final InlineSpan msg = (ra > 0 && ra < fa && sub < ra)
        ? TextSpan(children: [
            const TextSpan(text: '🚚 இன்னும் '),
            TextSpan(text: '₹${rupee(ra - sub)}', style: const TextStyle(fontWeight: FontWeight.w900)),
            const TextSpan(text: ' சேர்த்தால் டெலிவரி '),
            TextSpan(text: '₹${rupee(c2)}', style: const TextStyle(fontWeight: FontWeight.w900)),
            TextSpan(text: ' மட்டும் · ₹${rupee(fa)}-க்கு மேல் '),
            const TextSpan(text: 'இலவசம்', style: TextStyle(fontWeight: FontWeight.w900)),
          ])
        : TextSpan(children: [
            const TextSpan(text: '🚚 இன்னும் '),
            TextSpan(text: '₹${rupee(fa - sub)}', style: const TextStyle(fontWeight: FontWeight.w900)),
            const TextSpan(text: ' சேர்த்தால் '),
            const TextSpan(text: 'இலவச டெலிவரி', style: TextStyle(fontWeight: FontWeight.w900)),
          ]);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: const Color(0xFFFFF7ED), border: Border.all(color: const Color(0xFFFED7AA)), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text.rich(TextSpan(style: ts(13, w: w7, c: const Color(0xFF9A3412), h: 1.45), children: [msg])),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(value: pct, minHeight: 6, backgroundColor: const Color(0xFFFED7AA), color: const Color(0xFFF97316)),
        ),
      ]),
    );
  }

  Widget _item(CartLine c) {
    final p = c.product, pk = c.pack, q = c.qty;
    final o = pk.offer;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(color: P.card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: P.bd)),
          clipBehavior: Clip.antiAlias,
          child: Img(p.photo, emoji: p.emoji, emojiSize: 26),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p.brand.isNotEmpty ? '${p.brand} ' : ''}${p.name}', maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(13.5, w: w8, h: 1.3)),
            if (pk.w.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(color: P.card3, borderRadius: BorderRadius.circular(6)),
                child: Text(pk.w, style: ts(12, w: w7, c: P.mu2)),
              ),
            const SizedBox(height: 3),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 5, children: [
              Text('₹${rupee(pk.price * q)}', style: pop(14.5)),
              if (o != null) Text('₹${rupee(o.mrp * q)}', style: ts(12, c: P.mu, deco: TextDecoration.lineThrough)),
              if (q > 1) Text('₹${rupee(pk.price)} × $q', style: ts(12, c: P.mu)),
            ]),
          ]),
        ),
        QtyStepper(
          qty: q,
          height: 36,
          btnW: 34,
          font: 14,
          minusIcon: q == 1 ? const Icon(Icons.delete_outline, color: Colors.white, size: 18) : null,
          onMinus: () {
            Sfx.remove();
            final snap = q == 1 ? [CartLine(p, c.packIdx, 1)] : null;
            S.change(p, c.packIdx, -1);
            if (snap != null) toast('🗑️ கூடையிலிருந்து நீக்கப்பட்டது', action: 'மீண்டும் சேர்', onAction: () => S.restoreLines(snap));
          },
          onPlus: () => CartOps.chg(p, c.packIdx, 1, stock: false),
        ),
      ]),
    );
  }

  static bool profOk(Map<String, dynamic> p) =>
      js(p['nm']).isNotEmpty && RegExp(r'^[6-9]\d{9}$').hasMatch(js(p['ph'])) && js(p['ad']).length >= 5;

  // ── டெலிவரி முகவரி card ──
  Widget _addrCard(AppState s, Shop? sh) {
    final pr = s.profGet();
    final pinOk = pr != null && pr['lat'] != null;
    final svc = pinOk && sh != null ? svcCheck(sh, jz(pr['lat']), jz(pr['lng'])) : null;
    final ph = pr != null ? js(pr['ph']).replaceAllMapped(RegExp(r'^(\d{5})(\d{5})$'), (m) => '${m[1]} ${m[2]}') : '';
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.location_on_outlined, color: Color(0xFFDC2626), size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text('டெலிவரி முகவரி', style: ts(14.5, w: w8))),
          if (pr != null) TextButton(onPressed: () => showAddressSheet(), child: Text('மாற்று', style: ts(13, w: w8, c: P.g2))),
        ]),
        const SizedBox(height: 6),
        if (pr == null)
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: P.g, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => showAddressSheet(),
            child: Text('+ டெலிவரி முகவரியைச் சேர்க்கவும்', style: ts(14, w: w8, c: P.g2)),
          )
        else
          InkWell(
            onTap: () => showAddressSheet(),
            borderRadius: BorderRadius.circular(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: P.gc, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.home_outlined, color: P.g2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${js(pr['nm'])} · $ph', style: ts(14, w: w8)),
                  Text('${js(pr['ad'])}${js(pr['area']).isNotEmpty ? ', ${js(pr['area'])}' : ''}', style: ts(12.5, c: P.mu2, h: 1.4)),
                  const SizedBox(height: 4),
                  if (!pinOk)
                    GestureDetector(
                      onTap: _pinFromCart,
                      child: Text('📌 வரைபடத்தில் குறிக்க ›', style: ts(12.5, w: w8, c: const Color(0xFFB45309))),
                    )
                  else if (svc != null && !svc.ok)
                    Text('⚠️ ${svc.msg}', style: ts(12.5, w: w8, c: const Color(0xFFB91C1C)))
                  else
                    Row(children: [
                      Icon(Icons.place, size: 14, color: P.g2),
                      const SizedBox(width: 3),
                      Text('வரைபடத்தில் குறிக்கப்பட்டது', style: ts(12, w: w7, c: P.g2)),
                    ]),
                ]),
              ),
              Icon(Icons.chevron_right, color: P.mu),
            ]),
          ),
      ]),
    );
  }

  Future<void> _pinFromCart() async {
    final pin = await openMapPick();
    if (pin != null) savePinToProfile(pin);
  }

  // ── 🕐 டெலிவரி நேரம்: இப்போதே / பின்னர் (முன்பதிவு) ──
  Widget _schCard(Shop sh, bool closedNow, String eta) {
    if (closedNow && ckMode == 'now') ckMode = 'later'; // HTML schCardHTML
    final days = ckMode == 'later' ? schDays(sh) : <SchDay>[];
    if (ckDay >= days.length) ckDay = 0;
    final D = days.isNotEmpty ? days[ckDay] : null;
    // HTML .sch-tg button
    Widget tg(String mode, String t, String sub, {bool disabled = false}) {
      final on = ckMode == mode;
      return Expanded(
        child: Opacity(
          opacity: disabled ? .5 : 1,
          child: GestureDetector(
            onTap: disabled
                ? null
                : () => setState(() {
                      ckMode = mode;
                      if (mode == 'now') ckWhen = null;
                    }),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: on ? P.gc : P.card2,
                border: Border.all(color: on ? P.g : P.bd, width: 1.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: ts(14, w: w8)),
                const SizedBox(height: 2),
                Text(sub, style: ts(12, c: P.mu2, h: 1.35)),
              ]),
            ),
          ),
        ),
      );
    }

    Widget note(String t) => Padding(padding: const EdgeInsets.only(top: 10), child: Text(t, style: ts(12.5, w: w7, c: P.mu2)));

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Text('🕐', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text('டெலிவரி நேரம்', style: ts(14.5, w: w8)),
        ]),
        const SizedBox(height: 10),
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          tg('now', '⚡ இப்போதே', closedNow ? 'கடை மூடியுள்ளது' : (eta.isNotEmpty ? eta : 'உடனே'), disabled: closedNow),
          const SizedBox(width: 8),
          tg('later', '📅 பின்னர்', 'முன்பதிவு · 7 நாள் வரை'),
        ])),
        if (ckMode == 'later') ...[
          if (D == null)
            note('இந்தக் கடைக்கு முன்பதிவு நேரம் இல்லை')
          else ...[
            const SizedBox(height: 12),
            // HTML .sch-days
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (var i = 0; i < days.length; i++)
                  GestureDetector(
                    onTap: () => setState(() {
                      ckDay = i;
                      ckWhen = null;
                    }),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 64),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: i == ckDay ? P.g : P.card,
                        border: Border.all(color: i == ckDay ? P.g : P.bd, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(children: [
                        Text(days[i].chip, style: ts(13, w: w8, c: i == ckDay ? Colors.white : P.text)),
                        Text(days[i].sub, style: ts(12, c: i == ckDay ? const Color(0xD9FFFFFF) : P.mu2)),
                      ]),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 10),
            // HTML .sch-slots: 2 நெடுவரிசை
            LayoutBuilder(builder: (_, c) {
              final w = (c.maxWidth - 8) / 2;
              return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final x in D.slots)
                  GestureDetector(
                    onTap: () => setState(() {
                      ckWhen = x;
                      ckWhenLabel = '${D.full} · ${x.lb}';
                    }),
                    child: Container(
                      width: w,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ckWhen?.at == x.at ? P.gc : P.card,
                        border: Border.all(color: ckWhen?.at == x.at ? P.g : P.bd, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(x.lb, textAlign: TextAlign.center, style: ts(13, w: w7, c: ckWhen?.at == x.at ? P.g2 : P.text)),
                    ),
                  ),
              ]);
            }),
            note(ckWhen != null ? '✅ $ckWhenLabel' : '👆 ஒரு நேரத்தைத் தேர்ந்தெடுங்கள்'),
          ],
        ],
      ]),
    );
  }

  Widget _bar(AppState s) {
    final sh = _shop(s);
    final sub = s.cartAmount;
    final t = calcOrderTotals(sh, sub);
    final pr = s.profGet();
    final closed = sh != null && !sh.acceptingOrders;
    final closedNow = sh != null && !closed && !sh.isOpenNow;
    final minO = sh != null ? jz(sh.m['min_order']) : 0.0;
    final below = minO > 0 && sub < minO;
    final pinOk = pr != null && pr['lat'] != null;
    final svc = pinOk && sh != null ? svcCheck(sh, jz(pr['lat']), jz(pr['lng'])) : null;
    final blocked = below || closed || (svc != null && !svc.ok) || (ckMode == 'later' && ckWhen == null) || (ckMode == 'now' && closedNow);
    String? reason;
    if (closed) {
      reason = '⛔ ${sh!.name} தற்போது ஆர்டர் ஏற்கவில்லை';
    } else if (below) {
      reason = '🧾 குறைந்தபட்ச ஆர்டர் ₹${rupee(minO)} — இன்னும் ₹${rupee(minO - sub)} பொருட்கள் சேர்க்கவும்';
    } else if (svc != null && !svc.ok) {
      reason = '⚠️ ${svc.msg}';
    } else if (ckMode == 'now' && closedNow) {
      reason = '🕐 கடை இப்போது மூடியுள்ளது — 📅 பின்னர் என்பதில் நேரத்தைத் தேர்ந்தெடுங்கள்';
    } else if (ckMode == 'later' && ckWhen == null) {
      reason = '👆 ஒரு நேரத்தைத் தேர்ந்தெடுங்கள்';
    }
    final label = _busy
        ? '⏳ ஆர்டர் செய்கிறது...'
        : (pr != null ? (ckMode == 'later' ? '📅 முன்பதிவு செய் →' : 'ஆர்டர் செய் →') : 'முகவரி சேர்த்து தொடர் →');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(color: P.card, border: Border(top: BorderSide(color: P.bd)), boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, -4))]),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // பொத்தான் ஏன் செயல்படவில்லை என்று பொத்தானுக்கு மேலேயே (உள்ள வரிகளே)
          if (reason != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(reason, style: ts(13, w: w8, c: const Color(0xFFB91C1C), h: 1.4)),
            ),
          Row(children: [
            Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('மொத்தம்', style: ts(13, w: w7, c: P.mu2)),
              Text('₹${rupee(t.tot)}', style: pop(20)),
            ]),
            const SizedBox(width: 14),
            Expanded(child: GreenButton(label, onTap: blocked || _busy ? null : _order)),
          ]),
        ]),
      ),
    );
  }

  // ── கூடையிலிருந்து நேராக ஆர்டர் (server-ல் விலை, டெலிவரி, மொத்தம் சரிபார்க்கப்படும்) ──
  Future<void> _order() async {
    if (_busy) return;
    final s = AppState.I;
    final its = s.cart.values.toList();
    if (its.isEmpty) return;
    final sh = _shop(s);
    final sub0 = s.cartAmount;
    var p = s.profRaw();
    if (!profOk(p)) {
      final ok = await showAddressSheet(thenOrder: true, total: calcOrderTotals(sh, sub0).tot);
      if (!ok || !mounted) return;
      p = s.profRaw();
      if (!profOk(p)) return;
    }
    setState(() => _busy = true);
    var again = false;
    try {
      ckCid ??= uuid4();
      final ad = js(p['ad']), area = js(p['area']);
      final fullAd = ad + (area.isNotEmpty && !ad.contains(area) ? ', $area' : '');
      final shopId = s.cartShopId ?? kDefaultShopId;
      final sched = ckMode == 'later' && ckWhen != null;
      final params = <String, dynamic>{
        'p_client_order_id': ckCid,
        'p_shop_id': shopId,
        'p_name': js(p['nm']),
        'p_phone': js(p['ph']),
        'p_address': fullAd,
        'p_note': ckNote.trim(),
        'p_items': its.map((i) => {'product_id': i.product.id, 'pack': i.pack.w, 'qty': i.qty}).toList(),
        'p_expected_total': calcOrderTotals(sh, sub0).tot,
        'p_lat': p['lat'],
        'p_lng': p['lng'],
        if (sched) 'p_sched_at': ckWhen!.at,
        if (sched) 'p_slot': ckWhenLabel,
      };
      final res = await Orders.placeOrder(params);
      if (res['ok'] != true) {
        final code = js(res['code']);
        final msg = js(res['msg']).isNotEmpty ? js(res['msg']) : 'ஆர்டர் செய்ய முடியவில்லை — மீண்டும் முயற்சிக்கவும்';
        if (code == 'PRICE_CHANGED' || code == 'ITEM_GONE' || code == 'OUT_OF_STOCK') {
          ckCid = null;
          toast('⚠️ $msg');
          await s.reloadAndRefreshCart(); // HTML: loadFromSupabase() → refreshCartPrices()
          return;
        }
        if (code == 'RATE_LIMIT' || code == 'BUSY' || code == 'SHOP_CLOSED' || code == 'SCHED') ckCid = null;
        if (code == 'SCHED') ckWhen = null;
        if (code == 'SHOP_CLOSED' && ckMode == 'now' && sh != null && sh.acceptingOrders) {
          ckMode = 'later';
          toast('🕐 கடை இப்போது மூடியுள்ளது — 📅 பின்னர் என்பதில் நேரத்தைத் தேர்ந்தெடுங்கள்');
          return;
        }
        toast('⚠️ $msg');
        if (code == 'NAME' || code == 'PHONE' || code == 'ADDRESS') {
          if (mounted) setState(() => _busy = false);
          again = await showAddressSheet(thenOrder: true, total: calcOrderTotals(sh, sub0).tot);
          return;
        }
        if (code == 'OUT_OF_AREA' || code == 'PIN_NEEDED') {
          if (mounted) setState(() => _busy = false);
          await _pinFromCart();
        }
        return;
      }
      // இனி காட்டப்படும் ஒவ்வொரு எண்ணும் server-லிருந்து
      final oNo = js(res['order_number']);
      final sub = jz(res['subtotal']), del = jz(res['delivery_fee']), tot = jz(res['total']);
      final lines = res['items'] is List ? (res['items'] as List).whereType<Map>().toList() : <Map>[];
      final now = DateTime.now();
      final schedLbl = sched ? ckWhenLabel : '';
      Orders.I.saveLocal({
        'oNo': oNo,
        'date': fmtDate(now),
        'ts': now.millisecondsSinceEpoch,
        'nm': js(p['nm']),
        'ph': js(p['ph']),
        'ad': fullAd,
        'shopId': shopId,
        'shopName': sh?.name ?? '',
        'its': lines
            .map((l) => {'n': js(l['name']), 'full': js(l['name']), 'w': js(l['pack']), 'q': jz(l['qty']), 'up': jz(l['unit_price']), 't': jz(l['total']), 'pid': l['product_id']})
            .toList(),
        'sub': sub,
        'del': del,
        'tot': tot,
        'payment': 'COD',
        'oid': js(res['id']),
        'cid': ckCid,
        'nt': ckNote.trim(),
        'cs': {'o': true, 'i': true},
        'sched': schedLbl,
      });
      ckCid = null;
      ckNote = '';
      _note.clear();
      ckMode = 'now';
      ckWhen = null;
      ckDay = 0;
      Sfx.checkout();
      s.clearCart();
      Orders.I.fetch(force: true);
      // அனுமதி ஏற்கனவே இருந்தால் இந்த ஆர்டரை அமைதியாக push-உடன் இணை
      Push.enable(js(res['id']), js(p['ph']), silent: true);
      await showOrderSuccess(oNo: oNo, date: fmtDate(now), shopName: sh?.name ?? '', sub: sub, del: del, tot: tot, oid: js(res['id']), ph: js(p['ph']));
      if (schedLbl.isNotEmpty) toast('📅 முன்பதிவு: $schedLbl');
    } catch (_) {
      toast('⚠️ Network பிரச்சனை — மீண்டும் முயற்சிக்கவும்');
    } finally {
      if (mounted) setState(() => _busy = false);
      if (again && mounted) unawaited(_order());
    }
  }
}

// ரசீதின் கீழ் zig-zag விளிம்பு
class _ZigZag extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const r = 18.0, z = 8.0;
    final p = Path()
      ..moveTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(size.width - r, 0)
      ..quadraticBezierTo(size.width, 0, size.width, r)
      ..lineTo(size.width, size.height - z);
    var x = size.width;
    var up = false;
    while (x > 0) {
      x -= z;
      p.lineTo(x < 0 ? 0 : x, up ? size.height - z : size.height);
      up = !up;
    }
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
