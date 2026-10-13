// சிட்டை — பல திரைகளில் பயன்படும் பொதுப் பகுதிகள்
import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'nav.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';

AppState get S => AppState.I;

// இரவு நிறம் மாறியதும் எல்லாத் திரைகளையும் மீண்டும் வரை
void rebuildAllWidgets() {
  final c = Nav.root.currentContext;
  if (c == null) return;
  void r(Element e) {
    e.markNeedsBuild();
    e.visitChildren(r);
  }

  (c as Element).visitChildren(r);
}

// ═══ Toast (கீழே சிறிய கருப்புச் செய்தி) ═══
OverlayEntry? _toastE;
Timer? _toastT;
void toast(String msg) {
  final ov = Nav.root.currentState?.overlay;
  if (ov == null) return;
  _toastT?.cancel();
  _toastE?.remove();
  _toastE = OverlayEntry(
    builder: (c) => Positioned(
      left: 16,
      right: 16,
      bottom: MediaQuery.of(c).padding.bottom + 140,
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 220),
            builder: (_, v, ch) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: ch)),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2C34),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 2))],
                ),
                child: Text(msg, textAlign: TextAlign.center, style: ts(14, w: w7, c: const Color(0xFFE9EDEF), h: 1.45)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  ov.insert(_toastE!);
  _toastT = Timer(const Duration(milliseconds: 2600), () {
    _toastE?.remove();
    _toastE = null;
  });
}

// ═══ வெளி link-கள் (WhatsApp / அழை / இணையதளம்) ═══
Future<void> openUrl(String url) async {
  try {
    final u = Uri.parse(url);
    final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
    if (!ok) toast('திறக்க முடியவில்லை');
  } catch (_) {
    toast('திறக்க முடியவில்லை');
  }
}

void waHelp([String? msg]) {
  final n = js(S.waNum).replaceAll(RegExp(r'\D'), '');
  final full = n.length == 10 ? '91$n' : n;
  openUrl('https://wa.me/$full?text=${Uri.encodeComponent(msg ?? 'வணக்கம் சிட்டை, எனக்கு உதவி வேண்டும்.')}');
}

// ═══ படம்: ஏற்றும் வரை மறைந்து, பிறகு மெல்லத் தெரியும்; உடைந்தால் emoji ═══
class Img extends StatelessWidget {
  final String url;
  final String emoji;
  final BoxFit fit;
  final double emojiSize;
  const Img(this.url, {super.key, this.emoji = '🛍️', this.fit = BoxFit.cover, this.emojiSize = 32});

  Widget _emo() => Center(child: Text(emoji, style: TextStyle(fontSize: emojiSize)));

  @override
  Widget build(BuildContext context) {
    final u = url.replaceAll(RegExp(r'#cut$'), '').trim();
    if (u.isEmpty) return _emo();
    if (u.startsWith('data:image/')) {
      try {
        final i = u.indexOf(',');
        return Image.memory(base64Decode(u.substring(i + 1)), fit: fit, errorBuilder: (_, __, ___) => _emo());
      } catch (_) {
        return _emo();
      }
    }
    if (!u.startsWith('http')) return _emo();
    return CachedNetworkImage(
      imageUrl: u,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, __) => const SizedBox.shrink(),
      errorWidget: (_, __, ___) => _emo(),
    );
  }
}

// ═══ பொத்தான்கள் ═══
class GreenButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;
  const GreenButton(this.label, {super.key, this.onTap, this.height = 52});

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Opacity(
      opacity: on ? 1 : .55,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient: kBtnGrad,
            borderRadius: BorderRadius.circular(14),
            boxShadow: on ? const [BoxShadow(color: Color(0x47008069), blurRadius: 16, offset: Offset(0, 6))] : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Center(child: Text(label, style: ts(16, w: w8, c: Colors.white))),
          ),
        ),
      ),
    );
  }
}

class Tap extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  const Tap({super.key, required this.child, this.onTap, this.radius = 12});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: child),
      );
}

// ═══ கூடை செயல்கள் (ஒலி, அதிர்வு, வேறு கடை கேள்வி, கையிருப்பு சோதனை) ═══
class CartOps {
  static bool oosStop(Product p) {
    if (p.oos) {
      toast('😔 ${p.name} — தற்போது கையிருப்பு இல்லை');
      return true;
    }
    return false;
  }

  // வேறு கடையின் பொருள்: "Cart-ஐ மாற்றவா?"
  static Future<bool> conflictOk(Product p) async {
    if (!S.conflicts(p)) return true;
    final c = Nav.ctx;
    if (c == null) return false;
    final ps = S.shopById(p.shopId), cs = S.shopById(S.cartShopId ?? '');
    final ok = await showDialog<bool>(
      context: c,
      builder: (d) => Dialog(
        backgroundColor: P.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🛒⚠️', style: TextStyle(fontSize: 38)),
            const SizedBox(height: 12),
            Text(
              'இந்த பொருள் "${ps?.name ?? 'வேறு கடை'}" கடையைச் சேர்ந்தது. தற்போதைய "${cs?.name ?? ''}" Cart-ஐ மாற்றி புதிய கடையில் தொடர வேண்டுமா?',
              textAlign: TextAlign.center,
              style: ts(14.5, w: w7, h: 1.5),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: P.bd),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(d, false),
                  child: Text('ரத்து', style: ts(15, w: w8, c: P.mu2)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: GreenButton('தொடரவும்', height: 48, onTap: () => Navigator.pop(d, true))),
            ]),
          ]),
        ),
      ),
    );
    if (ok == true) {
      S.clearCart();
      return true;
    }
    return false;
  }

  static Future<void> add(Product p, int pi, {bool showToast = true}) async {
    if (oosStop(p)) return;
    if (!await conflictOk(p)) return;
    haptic();
    Sfx.add();
    S.addLine(p, pi);
    if (showToast) toast('🛒 ${p.name} சேர்க்கப்பட்டது!');
  }

  // stock:false = கூடைத் திரை (HTML cartChg: கையிருப்புச் சோதனை இல்லை)
  static void chg(Product p, int pi, int d, {bool stock = true}) {
    if (S.qtyOf(p, pi) == 0) return;
    if (stock && d > 0 && oosStop(p)) return;
    if (d > 0) {
      Sfx.add();
    } else {
      Sfx.remove();
    }
    S.change(p, pi, d);
  }

  static void rmAll(Product p) {
    S.removeAll(p);
    Sfx.remove();
    toast('🗑️ கூடையிலிருந்து நீக்கப்பட்டது');
  }
}

// ═══ − n + (பச்சை) ═══
class QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus, onPlus;
  final double height, btnW, font;
  final Widget? minusIcon;
  const QtyStepper({super.key, required this.qty, required this.onMinus, required this.onPlus, this.height = 38, this.btnW = 40, this.font = 15, this.minusIcon});

  @override
  Widget build(BuildContext context) {
    // தொடு இலக்கு: குறைந்தது 36 உயரம் × 34 அகலம் (முன்பு 28×24 வரை)
    final height = this.height < 36 ? 36.0 : this.height;
    final btnW = this.btnW < 34 ? 34.0 : this.btnW;
    Widget b(Widget c, VoidCallback f, String label) => SizedBox(
          width: btnW,
          height: height,
          child: Semantics(
            button: true,
            label: label,
            excludeSemantics: true,
            child: Material(color: Colors.transparent, child: InkWell(onTap: f, child: Center(child: c))),
          ),
        );
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: kBtnGrad,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x2E007A63), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        b(minusIcon ?? Text('−', style: ts(font + 5, w: w8, c: Colors.white)), onMinus, minusIcon != null ? 'கூடையிலிருந்து நீக்கு' : 'ஒன்று குறை'),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 18),
          child: Semantics(label: '$qty எண்ணிக்கை', excludeSemantics: true, child: Text('$qty', textAlign: TextAlign.center, style: pop(font, c: Colors.white, w: FontWeight.w700))),
        ),
        b(Text('+', style: ts(font + 5, w: w8, c: Colors.white)), onPlus, 'ஒன்று கூட்டு'),
      ]),
    );
  }
}

class OosTag extends StatelessWidget {
  final bool small;
  final String text;
  const OosTag({super.key, this.small = false, this.text = 'கையிருப்பு இல்லை'});
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 9 : 6, vertical: small ? 5 : 8),
        decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
        child: Text(text, textAlign: TextAlign.center, style: ts(small ? 11.5 : 12, w: w8, c: const Color(0xFFB91C1C))),
      );
}

// ═══ ♡ விருப்பம் ═══
class FavButton extends StatelessWidget {
  final Product p;
  final double size;
  const FavButton(this.p, {super.key, this.size = 28});
  @override
  Widget build(BuildContext context) {
    final on = context.select<AppState, bool>((s) => s.favHas(p));
    return Semantics(
      button: true,
      label: on ? 'விருப்பமானவையிலிருந்து நீக்கு' : 'விருப்பமானவையில் சேர்',
      excludeSemantics: true,
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final add = S.favToggle(p);
        toast(add ? '❤️ விருப்பமானவையில் சேர்க்கப்பட்டது' : 'விருப்பமானவையிலிருந்து நீக்கப்பட்டது');
      },
      child: Padding(
        padding: EdgeInsets.all(size < 40 ? (44 - size) / 2 : 4), // தொடு இலக்கு ≥ 44dp, தோற்றம் அதே
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: const Color(0xF0FFFFFF), shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1))]),
          alignment: Alignment.center,
          child: Text(on ? '❤️' : '♡', style: TextStyle(fontSize: size * .55, color: on ? const Color(0xFFE0245E) : const Color(0xFF8696A0), height: 1.1)),
        ),
      ),
    ));
  }
}

// ═══ கடைக்குள் பொருள் card (2 நெடுவரிசை) ═══
class ProductCard extends StatelessWidget {
  final Product p;
  const ProductCard(this.p, {super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final k = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6).toDouble(); // பெரிய எழுத்தில் வெட்டாமல் இருக்க
    final total = S.totalQtyOf(p);
    final inCart = total > 0;
    final single = p.packs.length == 1;
    final o1 = single ? p.packs[0].offer : null;
    final bo = p.bestOffer;
    final oos = p.oos;
    Widget action;
    if (oos && !inCart) {
      action = const OosTag();
    } else if (inCart) {
      action = Align(
        alignment: Alignment.centerLeft,
        child: QtyStepper(
          qty: total,
          btnW: 42,
          onMinus: () => single ? CartOps.chg(p, 0, -1) : Nav.openProduct(p),
          onPlus: () => single ? CartOps.chg(p, 0, 1) : Nav.openProduct(p),
        ),
      );
    } else {
      action = SizedBox(
        height: 38,
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: P.card,
            side: BorderSide(color: P.g, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => single ? CartOps.add(p, 0) : Nav.openProduct(p),
          child: Text('+ சேர்', style: ts(13.5, w: w8, c: P.g2)),
        ),
      );
    }
    return Stack(clipBehavior: Clip.none, children: [
      GestureDetector(
        onTap: () => Nav.openProduct(p),
        child: Container(
          decoration: BoxDecoration(
            color: P.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: inCart ? P.g : P.bd, width: inCart ? 2 : 1),
            boxShadow: [BoxShadow(color: inCart ? const Color(0x2E00A884) : const Color(0x0D143C32), blurRadius: inCart ? 14 : 8, offset: const Offset(0, 3))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(fit: StackFit.expand, children: [
                Container(color: P.card2),
                Opacity(
                  opacity: oos ? .6 : 1,
                  child: ColorFiltered(
                    colorFilter: oos ? const ColorFilter.matrix(_grey) : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                    child: Img(p.photo, emoji: p.emoji, emojiSize: 40),
                  ),
                ),
                if (bo != null)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: const BoxDecoration(color: Color(0xFFE8590C), borderRadius: BorderRadius.only(topRight: Radius.circular(10))),
                      child: Text('${bo.off}%${single ? '' : ' வரை'} தள்ளுபடி', style: ts(12, w: w8, c: Colors.white)),
                    ),
                  ),
                Positioned(right: 1, bottom: 1, child: FavButton(p)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
              decoration: inCart ? BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [P.card, P.card, P.gc], stops: const [0, .6, 1])) : null,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  height: 15 * k,
                  child: Text(p.brand.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, w: w7, c: P.mu2, ls: .5)),
                ),
                SizedBox(
                  height: 36 * k,
                  child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(12.5, w: w8, h: 1.35)),
                ),
                SizedBox(
                  height: 18 * k,
                  child: Text(single ? p.packs[0].w : '${p.packs.length} அளவுகள்', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, w: w7, c: P.mu2)),
                ),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₹${rupee(p.minPrice)}', style: pop(16)),
                  const SizedBox(width: 5),
                  if (single && o1 != null) Text('₹${rupee(o1.mrp)}', style: ts(12, c: P.mu, deco: TextDecoration.lineThrough)),
                  if (!single) Text('முதல்', style: ts(12, w: w7, c: P.mu)),
                ]),
                const SizedBox(height: 6),
                action,
              ]),
            ),
          ]),
        ),
      ),
      if (inCart)
        Positioned(
          top: -9,
          right: -9,
          child: Semantics(
            button: true,
            label: 'கூடையிலிருந்து நீக்கு',
            excludeSemantics: true,
            child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => CartOps.rmAll(p),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                shape: BoxShape.circle,
                border: Border.all(color: P.card, width: 3),
                boxShadow: const [BoxShadow(color: Color(0x59DC2626), blurRadius: 8, offset: Offset(0, 3))],
              ),
              alignment: Alignment.center,
              child: const Text('✕', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
        )),
    ]);
  }
}

const List<double> _grey = [
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
];

// ═══ முகப்பு வரிசைகளில் சிறிய பொருள் card (hx-p) ═══
class HxBtn extends StatelessWidget {
  final Product p;
  final int pi;
  const HxBtn(this.p, this.pi, {super.key});
  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final q = S.qtyOf(p, pi);
    if (q == 0 && p.oos) return const OosTag(small: true, text: 'இல்லை');
    if (q > 0) {
      return QtyStepper(qty: q, height: 28, btnW: 24, font: 13, onMinus: () => CartOps.chg(p, pi, -1), onPlus: () => CartOps.chg(p, pi, 1));
    }
    return Semantics(
      button: true,
      label: 'கூடையில் சேர்',
      excludeSemantics: true,
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => CartOps.add(p, pi, showToast: false),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36, minWidth: 64),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: P.card, border: Border.all(color: P.g, width: 1.5), borderRadius: BorderRadius.circular(9)),
        child: Text('சேர் +', style: ts(12, w: w8, c: const Color(0xFF00856B))),
      ),
    ));
  }
}

class HxCard extends StatelessWidget {
  final Product p;
  final int pi;
  final String badge;
  const HxCard(this.p, this.pi, {super.key, this.badge = ''});
  @override
  Widget build(BuildContext context) {
    final pk = p.packs[pi];
    final o = pk.offer;
    return GestureDetector(
      onTap: () => Nav.goProd(p),
      child: Container(
        width: 128,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: P.card,
          border: Border.all(color: P.bd),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0D143C32), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 96,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                Container(color: P.card2),
                Img(p.photo, emoji: p.emoji, emojiSize: 40),
                if (badge.isNotEmpty)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: const BoxDecoration(color: Color(0xFF16A34A), borderRadius: BorderRadius.only(bottomRight: Radius.circular(10))),
                      child: Text(badge, style: ts(12, w: w8, c: Colors.white)),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6).toDouble(),
            child: Text('${p.brand.isNotEmpty ? '${p.brand} ' : ''}${p.name}', maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(12.5, w: w8, h: 1.3)),
          ),
          Text(pk.w, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, w: w7, c: P.mu)),
          const Spacer(),
          Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 3, children: [
            Text('₹${rupee(pk.price)}', style: pop(14)),
            if (o != null) Text('₹${rupee(o.mrp)}', style: ts(12, c: P.mu, deco: TextDecoration.lineThrough)),
          ]),
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerRight, child: HxBtn(p, pi)),
        ]),
      ),
    );
  }
}

// ═══ பிரிவுத் தலைப்பு ═══
class SecHead extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? more;
  final VoidCallback? onMore;
  const SecHead(this.title, {super.key, this.icon, this.more, this.onMore});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 10, 10),
        child: Row(children: [
          if (icon != null) ...[Icon(icon, size: 21, color: P.g2), const SizedBox(width: 8)],
          Expanded(child: Text(title, style: ts(16.5, w: w8))),
          if (more != null)
            TextButton(
              onPressed: onMore,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(more!, style: ts(13, w: w8, c: P.g2)),
                Icon(Icons.chevron_right, size: 18, color: P.g2),
              ]),
            ),
        ]),
      );
}

// ═══ ஏற்றுதல் / பிழை நிலைகள் ═══
class StateBox extends StatelessWidget {
  final String ic, title, sub;
  final bool retry;
  const StateBox(this.ic, this.title, {super.key, this.sub = '', this.retry = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
        child: Column(children: [
          Text(ic, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: ts(15, w: w8)),
          if (sub.isNotEmpty) ...[const SizedBox(height: 4), Text(sub, textAlign: TextAlign.center, style: ts(12.5, c: P.mu))],
          if (retry) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: P.g, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => S.runCloudLoad(),
              child: Text('மீண்டும் முயற்சி', style: ts(14, w: w8, c: Colors.white)),
            ),
          ],
        ]),
      );
}

class Skeleton extends StatefulWidget {
  final int n;
  const Skeleton(this.n, {super.key});
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final col = Color.lerp(P.card3, P.bd, _c.value)!;
        Widget bar(double w, double h) => Container(width: w, height: h, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(8)));
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            for (var i = 0; i < widget.n; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: P.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: P.bd)),
                child: Row(children: [
                  Container(width: 58, height: 58, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(16))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (_, c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        bar(c.maxWidth * .6, 14),
                        const SizedBox(height: 8),
                        bar(c.maxWidth * .85, 11),
                      ]),
                    ),
                  ),
                ]),
              ),
          ]),
        );
      },
    );
  }
}

// ═══ வட்டமான emoji / படப் பெட்டி ═══
class KindCircle extends StatelessWidget {
  final Kind k;
  final double size;
  final bool ring;
  const KindCircle(this.k, {super.key, this.size = 72, this.ring = false});
  @override
  Widget build(BuildContext context) {
    final img = S.kindImg[k.id] ?? '';
    final cut = img.endsWith('#cut');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: hexColor(S.kindBg(k)),
        shape: BoxShape.circle,
        boxShadow: [
          if (ring) BoxShadow(color: P.g, spreadRadius: 2.5),
          const BoxShadow(color: Color(0x0D143C32), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: img.isEmpty
          ? Text(k.e, style: TextStyle(fontSize: size * .45))
          : cut
              ? Padding(padding: EdgeInsets.all(size * .09), child: Img(img, emoji: k.e, fit: BoxFit.contain, emojiSize: size * .45))
              : SizedBox.expand(child: Img(img, emoji: k.e, fit: BoxFit.cover, emojiSize: size * .45)),
    );
  }
}

// ═══ 📢 ஓடும் அறிவிப்புப் பட்டை ═══
class NoticeBar extends StatefulWidget {
  final String text;
  const NoticeBar(this.text, {super.key});
  @override
  State<NoticeBar> createState() => _NoticeBarState();
}

class _NoticeBarState extends State<NoticeBar> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  bool _hold = false;
  @override
  void initState() {
    super.initState();
    final secs = (widget.text.length / 4).round().clamp(12, 120).toInt();
    _c = AnimationController(vsync: this, duration: Duration(seconds: secs))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = ts(13.5, w: w8, c: const Color(0xFF7A4B00));
    return GestureDetector(
      onTapDown: (_) => setState(() {
        _hold = true;
        _c.stop();
      }),
      onTapUp: (_) => setState(() {
        _hold = false;
        _c.repeat();
      }),
      onTapCancel: () {
        if (_hold) _c.repeat();
        _hold = false;
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFFFF7E6), border: Border.all(color: const Color(0xFFF6DFB5)), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Text('📢', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRect(
              child: LayoutBuilder(builder: (_, c) {
                final tp = TextPainter(text: TextSpan(text: widget.text, style: style), textDirection: TextDirection.ltr, maxLines: 1)..layout();
                final w = tp.width + 60;
                return SizedBox(
                  height: tp.height + 2,
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, __) => Stack(clipBehavior: Clip.none, children: [
                      Positioned(left: -_c.value * w, top: 0, child: Text(widget.text, style: style, maxLines: 1, softWrap: false)),
                      Positioned(left: -_c.value * w + w, top: 0, child: Text(widget.text, style: style, maxLines: 1, softWrap: false)),
                    ]),
                  ),
                );
              }),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══ HTML-ன் அதே line icons (SVG path → Flutter Path) ═══
// path / circle / rect (rx) மட்டும்; "f" class கொண்டவை active ஆகும்போது 20% நிறம் நிரம்பும்
class LineIcon extends StatelessWidget {
  final String svg;
  final double size, stroke;
  final Color color;
  final double fillAlpha; // 0 = நிரப்பு இல்லை
  const LineIcon(this.svg, {super.key, this.size = 20, this.stroke = 2, required this.color, this.fillAlpha = 0});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _LinePainter(_SvgShapes.of(svg), stroke, color, fillAlpha)),
      );
}

class _SvgShapes {
  final List<Path> all = [], fill = [];
  static final Map<String, _SvgShapes> _cache = {};
  static _SvgShapes of(String svg) => _cache.putIfAbsent(svg, () => _SvgShapes._(svg));

  static double _a(String tag, String n) {
    final m = RegExp('\\b$n="([-0-9.]+)"').firstMatch(tag);
    return m == null ? 0 : double.parse(m.group(1)!);
  }

  _SvgShapes._(String svg) {
    for (final m in RegExp(r'<(path|circle|rect)\b([^>]*)/?>').allMatches(svg)) {
      final tag = m.group(2)!;
      final f = tag.contains('class="f"');
      Path p;
      switch (m.group(1)) {
        case 'circle':
          p = Path()..addOval(Rect.fromCircle(center: Offset(_a(tag, 'cx'), _a(tag, 'cy')), radius: _a(tag, 'r')));
          break;
        case 'rect':
          final r = Rect.fromLTWH(_a(tag, 'x'), _a(tag, 'y'), _a(tag, 'width'), _a(tag, 'height'));
          p = Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(_a(tag, 'rx'))));
          break;
        default:
          final d = RegExp(r'\bd="([^"]*)"').firstMatch(tag)?.group(1) ?? '';
          p = _parse(d);
      }
      all.add(p);
      if (f) fill.add(p);
    }
  }

  static Path _parse(String d) {
    final p = Path();
    final tok = RegExp(r'[MmLlHhVvAaZzCcSsQq]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?').allMatches(d).map((x) => x.group(0)!).toList();
    var i = 0;
    var cmd = 'M';
    double x = 0, y = 0, sx = 0, sy = 0;
    bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
    double n() => double.parse(tok[i++]);
    while (i < tok.length) {
      if (isCmd(tok[i])) cmd = tok[i++];
      final rel = cmd == cmd.toLowerCase();
      switch (cmd.toUpperCase()) {
        case 'M':
          var nx = n(), ny = n();
          if (rel) {
            nx += x;
            ny += y;
          }
          x = nx;
          y = ny;
          sx = x;
          sy = y;
          p.moveTo(x, y);
          cmd = rel ? 'l' : 'L'; // அடுத்த எண்கள் = lineTo
          break;
        case 'L':
          var nx = n(), ny = n();
          if (rel) {
            nx += x;
            ny += y;
          }
          x = nx;
          y = ny;
          p.lineTo(x, y);
          break;
        case 'H':
          final v = n();
          x = rel ? x + v : v;
          p.lineTo(x, y);
          break;
        case 'V':
          final v = n();
          y = rel ? y + v : v;
          p.lineTo(x, y);
          break;
        case 'C':
          final v = [n(), n(), n(), n(), n(), n()];
          if (rel) {
            for (var k = 0; k < 6; k += 2) {
              v[k] += x;
              v[k + 1] += y;
            }
          }
          p.cubicTo(v[0], v[1], v[2], v[3], v[4], v[5]);
          x = v[4];
          y = v[5];
          break;
        case 'Q':
          final v = [n(), n(), n(), n()];
          if (rel) {
            v[0] += x;
            v[1] += y;
            v[2] += x;
            v[3] += y;
          }
          p.quadraticBezierTo(v[0], v[1], v[2], v[3]);
          x = v[2];
          y = v[3];
          break;
        case 'A':
          final rx = n(), ry = n(), rot = n(), large = n() != 0, sweep = n() != 0;
          var nx = n(), ny = n();
          if (rel) {
            nx += x;
            ny += y;
          }
          p.arcToPoint(Offset(nx, ny), radius: Radius.elliptical(rx, ry), rotation: rot, largeArc: large, clockwise: sweep);
          x = nx;
          y = ny;
          break;
        case 'Z':
          p.close();
          x = sx;
          y = sy;
          break;
        default:
          i++; // தெரியாதது: தவிர்
      }
    }
    return p;
  }
}

class _LinePainter extends CustomPainter {
  final _SvgShapes s;
  final double stroke, fillAlpha;
  final Color color;
  _LinePainter(this.s, this.stroke, this.color, this.fillAlpha);
  @override
  void paint(Canvas c, Size z) {
    c.scale(z.width / 24, z.height / 24);
    if (fillAlpha > 0) {
      final f = Paint()..color = color.withValues(alpha: fillAlpha);
      for (final p in s.fill) {
        c.drawPath(p, f);
      }
    }
    final st = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final p in s.all) {
      c.drawPath(p, st);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter o) => o.color != color || o.stroke != stroke || o.fillAlpha != fillAlpha || o.s != s;
}

// HTML .wa-toggle (52×30, knob 22)
class WaToggle extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onChanged;
  const WaToggle({super.key, required this.on, required this.onChanged});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onChanged(!on),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 52,
          height: 30,
          decoration: BoxDecoration(
            color: on ? const Color(0xFF00A884) : P.bd,
            border: Border.all(color: on ? const Color(0xFF00A884) : P.bd),
            borderRadius: BorderRadius.circular(15),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1))]),
            ),
          ),
        ),
      );
}

// HTML icon தொகுப்புகள்
const String kIcHome = '<path class="f" d="M3 10.5L12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>';
const String kIcShops = '<path class="f" d="M4 10v10h16V10"/><path d="M3 10l1.5-6h15L21 10M3 10h18M3 10a3 3 0 0 0 6 0 3 3 0 0 0 6 0 3 3 0 0 0 6 0M10 20v-5h4v5"/>';
const String kIcOrders = '<rect class="f" x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4V3h6v1M9 10h6M9 14h6M9 18h4"/>';
const String kIcCart = '<path d="M3 4h2l2.4 11.2a1.5 1.5 0 0 0 1.5 1.2h8.6a1.5 1.5 0 0 0 1.5-1.1L21 8H6.2"/><circle cx="9.5" cy="20" r="1.4"/><circle cx="17.5" cy="20" r="1.4"/>';
const String kCxCart = '<path d="M3 4h2l2.2 10.2a1.5 1.5 0 0 0 1.5 1.2h8.6a1.5 1.5 0 0 0 1.5-1.1L20.5 8H6.2"/><circle cx="9.5" cy="19.5" r="1.4"/><circle cx="17" cy="19.5" r="1.4"/>';
const String kCxTruck = '<path d="M3 6h11v10H3zM14 10h4l3 3v3h-7"/><circle cx="7" cy="17.5" r="1.6"/><circle cx="17.5" cy="17.5" r="1.6"/>';
const String kCxTag = '<path d="M3 12V4h8l10 10-8 8z"/><circle cx="7.5" cy="8" r="1.3"/>';
const String kIcReceipt = '<path d="M6 3h12v18l-3-2-3 2-3-2-3 2z"/><path d="M9 8h6M9 12h6M9 16h3"/>';
const String kIcEdit = '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M14 6l4 4"/>';
// கணக்குப் பக்கம் (ACC_IC)
const Map<String, String> kAccIc = {
  'ord': '<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4V3h6v1M9 10h6M9 14h6M9 18h3"/>',
  'fav': '<path d="M12 20.5s-8-4.9-8-11A4.5 4.5 0 0 1 12 6.6 4.5 4.5 0 0 1 20 9.5c0 6.1-8 11-8 11z"/>',
  'loc': '<path d="M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
  'bell': '<path d="M6 16V11a6 6 0 0 1 12 0v5l2 2H4z"/><path d="M10 20a2 2 0 0 0 4 0"/>',
  'font': '<path d="M4 19l5-14 5 14M6 14h6M15 19l3-8 3 8M16 16.5h4"/>',
  'moon': '<path d="M20 14.5A8 8 0 0 1 9.5 4 8 8 0 1 0 20 14.5z"/>',
  'help': '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.6V14M12 17.3v.2"/>',
  'info': '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5v.2"/>',
  'lock': '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
  'doc': '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5M9 13h6M9 17h6"/>',
  'share': '<circle cx="18" cy="5" r="2.5"/><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="19" r="2.5"/><path d="M8.2 10.8l7.6-4.4M8.2 13.2l7.6 4.4"/>',
  'del': '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>',
};
