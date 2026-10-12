// சிட்டை — கூடை = Checkout (Phase 1: பொருட்கள், இலவச டெலிவரி பட்டை, பில். ஆர்டர் செய்தல் Phase 2-ல்)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static String ckNote = '';
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
        leading: IconButton(icon: Icon(Icons.arrow_back, color: P.text), onPressed: () => Nav.back()),
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
                  child: Text('$cnt', style: ts(10.5, w: w8, c: Colors.white)),
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
            SizedBox(width: 220, child: GreenButton('பொருட்களைப் பார்க்க', onTap: () => Nav.go('home'))),
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
      if (closedNow) _warn('🕐 ${sh!.name} இப்போது மூடியுள்ளது — டெலிவரி நேரத்தைத் தேர்ந்தெடுத்து முன்பதிவு செய்யலாம்', bg: const Color(0xFFFFF7E6), fg: const Color(0xFF9A5B00)),
      _freeBar(sh, sub),
      // பொருட்கள்
      _card(
        pad: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: Column(children: [
          Row(children: [
            Icon(Icons.shopping_bag_outlined, size: 19, color: P.g2),
            const SizedBox(width: 6),
            Expanded(child: Text('$cnt ${cnt == 1 ? 'பொருள்' : 'பொருட்கள்'}', style: ts(14, w: w8))),
            TextButton(onPressed: () => sh != null ? Nav.openShop(sh.id) : Nav.go('home'), child: Text('+ மேலும் சேர்', style: ts(13, w: w8, c: P.g2))),
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
      // முகவரி + நேரம் (Phase 2)
      _card(
        child: Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.location_on_outlined, color: Color(0xFFDC2626), size: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('டெலிவரி முகவரி & நேரம்', style: ts(14.5, w: w8)),
              Text('அடுத்த பதிப்பில் (Phase 2) — முகவரி, வரைபட pin, "இப்போதே / பின்னர்"', style: ts(12, c: P.mu)),
            ]),
          ),
        ]),
      ),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: P.bd)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: P.bd)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: P.g)),
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
              Row(children: [
                Icon(Icons.receipt_long_outlined, size: 19, color: P.g2),
                const SizedBox(width: 6),
                Text('சிட்டை', style: ts(15, w: w8)),
                const Spacer(),
                Text('பில் விவரம்', style: ts(12, w: w7, c: P.mu)),
              ]),
              const SizedBox(height: 10),
              _billRow('பொருட்களின் விலை', '₹${rupee(sub + saved)}'),
              if (saved > 0) _billRow('தள்ளுபடி', '− ₹${rupee(saved)}', green: true),
              _billRow('டெலிவரி கட்டணம்', t.del > 0 ? '₹${rupee(t.del)}' : 'இலவசம்', green: t.del <= 0),
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: _dash()),
              Row(children: [
                Text('மொத்தம்', style: ts(16, w: w9)),
                const Spacer(),
                Text('₹${rupee(t.tot)}', style: pop(19)),
              ]),
            ]),
          ),
        ),
      ),
      if (below) _warn('🧾 குறைந்தபட்ச ஆர்டர் ₹${rupee(minO)} — இன்னும் ₹${rupee(minO - sub)} பொருட்கள் சேர்க்கவும்'),
      Padding(
        padding: const EdgeInsets.all(14),
        child: Text('ஆர்டர் செய்வதன் மூலம் விதிமுறைகளை ஏற்கிறீர்கள்', textAlign: TextAlign.center, style: ts(12, c: P.mu)),
      ),
    ]);
  }

  Widget _dash() => LayoutBuilder(
        builder: (_, c) => Row(
          children: List.generate((c.maxWidth / 8).floor(), (_) => Container(width: 4, height: 1.2, margin: const EdgeInsets.only(right: 4), color: P.bd)),
        ),
      );

  Widget _billRow(String l, String v, {bool green = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(l, style: ts(14, w: w6, c: green ? P.g2 : P.mu2)),
          const Spacer(),
          Text(v, style: ts(14, w: w8, c: green ? P.g2 : P.text)),
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
                child: Text(pk.w, style: ts(11.5, w: w7, c: P.mu2)),
              ),
            const SizedBox(height: 3),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 5, children: [
              Text('₹${rupee(pk.price * q)}', style: pop(14.5)),
              if (o != null) Text('₹${rupee(o.mrp * q)}', style: ts(12, c: P.mu, deco: TextDecoration.lineThrough)),
              if (q > 1) Text('₹${rupee(pk.price)} × $q', style: ts(11.5, c: P.mu)),
            ]),
          ]),
        ),
        QtyStepper(
          qty: q,
          height: 34,
          btnW: 32,
          font: 14,
          minusIcon: q == 1 ? const Icon(Icons.delete_outline, color: Colors.white, size: 18) : null,
          onMinus: () {
            Sfx.remove();
            S.change(p, c.packIdx, -1);
          },
          onPlus: () => CartOps.chg(p, c.packIdx, 1),
        ),
      ]),
    );
  }

  Widget _bar(AppState s) {
    final sh = _shop(s);
    final t = calcOrderTotals(sh, s.cartAmount);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(color: P.card, border: Border(top: BorderSide(color: P.bd)), boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, -4))]),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('மொத்தம்', style: ts(12, w: w7, c: P.mu)),
            Text('₹${rupee(t.tot)}', style: pop(20)),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: GreenButton('ஆர்டர் செய் →', onTap: () => toast('🛵 ஆர்டர் செய்தல் அடுத்த பதிப்பில் (Phase 2) வரும்')),
          ),
        ]),
      ),
    );
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
