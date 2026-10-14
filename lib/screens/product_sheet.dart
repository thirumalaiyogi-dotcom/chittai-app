// Crispy — பொருள் விவரம் sheet: ஒவ்வொரு அளவுக்கும் "சேர்" / − n +, விளக்கம், பெரிய படம்
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';

Future<void> showProductSheet(BuildContext context, Product p) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProductSheet(p),
  );
}

// "#RC001" — admin-ல் உள்ள அதே பொருள் குறியீடு
String catSeqId(Product p) {
  const map = {
    'rice': 'RC', 'dals': 'DL', 'oils': 'OL', 'atta': 'AT', 'masala': 'MS', 'salt': 'SL', 'seeds': 'SD', 'biscuits': 'BS',
    'chips': 'CH', 'frozen': 'FZ', 'breakfast': 'BK', 'drinks': 'DR', 'tea': 'TE', 'soap': 'SP', 'cleaning': 'CL', 'sweets': 'SW'
  };
  var prefix = map[p.category] ?? p.category.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
  if (prefix.length > 2) prefix = prefix.substring(0, 2);
  if (prefix.isEmpty) prefix = 'GN';
  final same = AppState.I.prods.where((x) => x.category == p.category).toList()..sort((a, b) => jz(a.id).compareTo(jz(b.id)));
  final seq = same.indexWhere((x) => x.key == p.key) + 1;
  return '#$prefix${seq.toString().padLeft(3, '0')}';
}

void showImageViewer(BuildContext context, Product p) {
  if (p.photo.isEmpty) return;
  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierColor: Colors.black.withValues(alpha: .92),
    builder: (c) => GestureDetector(
      onTap: () => Navigator.pop(c),
      child: Stack(children: [
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            InteractiveViewer(maxScale: 4, child: ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * .7), child: Img(p.photo, emoji: p.emoji, fit: BoxFit.contain, emojiSize: 80))),
            const SizedBox(height: 14),
            Text('${catSeqId(p)}  ${p.name}', textAlign: TextAlign.center, style: ts(15, w: w7, c: Colors.white)),
          ]),
        ),
        Positioned(
          top: MediaQuery.of(c).padding.top + 10,
          right: 14,
          child: const CircleAvatar(backgroundColor: Color(0x33FFFFFF), child: Icon(Icons.close, color: Colors.white)),
        ),
      ]),
    ),
  );
}

class _ProductSheet extends StatelessWidget {
  final Product p;
  const _ProductSheet(this.p);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final idx = List.generate(p.packs.length, (i) => i)..sort((a, b) => packWeightVal(p.packs[a].w).compareTo(packWeightVal(p.packs[b].w)));
    var n = 0;
    double amt = 0;
    for (var i = 0; i < p.packs.length; i++) {
      final q = s.qtyOf(p, i);
      n += q;
      amt += p.packs[i].price * q;
    }
    final mq = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * .88),
      decoration: BoxDecoration(color: P.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(margin: const EdgeInsets.only(top: 8), width: 42, height: 5, decoration: BoxDecoration(color: P.bd, borderRadius: BorderRadius.circular(3)))),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          child: Row(children: [
            IconButton(icon: Icon(Icons.chevron_left, color: P.text, size: 30), onPressed: () => Navigator.pop(context)),
            GestureDetector(
              onTap: () => showImageViewer(context, p),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: P.card2, borderRadius: BorderRadius.circular(14), border: Border.all(color: P.bd)),
                clipBehavior: Clip.antiAlias,
                child: Img(p.photo, emoji: p.emoji, emojiSize: 28),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (p.brand.isNotEmpty) Text(p.brand, style: ts(12, w: w7, c: P.mu2)),
                Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(17, w: w8, h: 1.3)),
              ]),
            ),
            FavButton(p, size: 34),
            IconButton(tooltip: 'மூடு', icon: Icon(Icons.close, color: P.mu2), onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Divider(height: 1, color: P.bd),
        Flexible(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(14, 14, 14, 14), children: [
            Text('அளவைத் தேர்வு செய்யுங்கள்', style: ts(13.5, w: w8, c: P.mu2)),
            const SizedBox(height: 6),
            for (final i in idx) _row(s, i),
            if (p.description.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: P.card2, borderRadius: BorderRadius.circular(12)),
                child: Text(p.description, style: ts(13.5, c: P.mu2, h: 1.55)),
              ),
          ]),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: n == 0
              ? SizedBox(height: mq.padding.bottom + 6)
              : Container(
                  padding: EdgeInsets.fromLTRB(16, 10, 12, 10 + mq.padding.bottom),
                  decoration: BoxDecoration(color: P.card, border: Border(top: BorderSide(color: P.bd))),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('$n ${n == 1 ? 'பொருள்' : 'பொருட்கள்'}', style: ts(14, w: w8)),
                        Text('₹${rupee(round2(amt))}', style: pop(16, c: P.g2)),
                      ]),
                    ),
                    SizedBox(
                      width: 170,
                      child: GreenButton('கூடை பார் ›', height: 48, onTap: () {
                        Navigator.pop(context);
                        // HTML psGoCart: sheet மூடி, கூடை மேலே (back → கடைக்கே)
                        Future.delayed(const Duration(milliseconds: 250), Nav.openCart);
                      }),
                    ),
                  ]),
                ),
        ),
      ]),
    );
  }

  Widget _row(AppState s, int i) {
    final pk = p.packs[i];
    final q = s.qtyOf(p, i);
    final o = pk.offer;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: q > 0 ? P.gc : null, borderRadius: BorderRadius.circular(12), border: Border(bottom: BorderSide(color: q > 0 ? Colors.transparent : P.bd))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pk.w, style: ts(15.5, w: w8)),
            const SizedBox(height: 3),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
              Text('₹${rupee(pk.price)}', style: pop(16)),
              if (o != null) Text('₹${rupee(o.mrp)}', style: ts(13, c: P.mu, deco: TextDecoration.lineThrough)),
              if (o != null) Text('${o.off}% தள்ளுபடி', style: ts(12, w: w8, c: const Color(0xFF16A34A))),
            ]),
          ]),
        ),
        SizedBox(
          width: 104,
          height: 44,
          child: q > 0
              ? QtyStepper(qty: q, height: 44, btnW: 36, font: 17, onMinus: () => CartOps.chg(p, i, -1), onPlus: () => CartOps.chg(p, i, 1))
              : GreenButton('சேர்', height: 44, onTap: () => CartOps.add(p, i, showToast: false)),
        ),
      ]),
    );
  }
}
