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
    Widget b(Widget c, VoidCallback f) => SizedBox(
          width: btnW,
          height: height,
          child: Material(color: Colors.transparent, child: InkWell(onTap: f, child: Center(child: c))),
        );
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: kBtnGrad,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x2E007A63), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        b(minusIcon ?? Text('−', style: ts(font + 5, w: w8, c: Colors.white)), onMinus),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 18),
          child: Text('$qty', textAlign: TextAlign.center, style: pop(font, c: Colors.white, w: FontWeight.w700)),
        ),
        b(Text('+', style: ts(font + 5, w: w8, c: Colors.white)), onPlus),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final add = S.favToggle(p);
        toast(add ? '❤️ விருப்பமானவையில் சேர்க்கப்பட்டது' : 'விருப்பமானவையிலிருந்து நீக்கப்பட்டது');
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: const Color(0xF0FFFFFF), shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1))]),
          alignment: Alignment.center,
          child: Text(on ? '❤️' : '♡', style: TextStyle(fontSize: size * .55, color: on ? const Color(0xFFE0245E) : const Color(0xFF8696A0), height: 1.1)),
        ),
      ),
    );
  }
}

// ═══ கடைக்குள் பொருள் card (2 நெடுவரிசை) ═══
class ProductCard extends StatelessWidget {
  final Product p;
  const ProductCard(this.p, {super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
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
                      child: Text('${bo.off}%${single ? '' : ' வரை'} தள்ளுபடி', style: ts(11, w: w8, c: Colors.white)),
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
                  height: 15,
                  child: Text(p.brand.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11, w: w7, c: P.mu2, ls: .5)),
                ),
                SizedBox(
                  height: 36,
                  child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(12.5, w: w8, h: 1.35)),
                ),
                SizedBox(
                  height: 18,
                  child: Text(single ? p.packs[0].w : '${p.packs.length} அளவுகள்', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, w: w7, c: P.mu2)),
                ),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₹${rupee(p.minPrice)}', style: pop(16)),
                  const SizedBox(width: 5),
                  if (single && o1 != null) Text('₹${rupee(o1.mrp)}', style: ts(12, c: P.mu, deco: TextDecoration.lineThrough)),
                  if (!single) Text('முதல்', style: ts(11.5, w: w7, c: P.mu)),
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
          child: GestureDetector(
            onTap: () => CartOps.rmAll(p),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                shape: BoxShape.circle,
                border: Border.all(color: P.card, width: 3),
                boxShadow: const [BoxShadow(color: Color(0x59DC2626), blurRadius: 8, offset: Offset(0, 3))],
              ),
              alignment: Alignment.center,
              child: const Text('✕', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
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
    return GestureDetector(
      onTap: () => CartOps.add(p, pi, showToast: false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: P.card, border: Border.all(color: P.g, width: 1.5), borderRadius: BorderRadius.circular(9)),
        child: Text('சேர் +', style: ts(12, w: w8, c: const Color(0xFF00856B))),
      ),
    );
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
                      child: Text(badge, style: ts(11.5, w: w8, c: Colors.white)),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: Text('${p.brand.isNotEmpty ? '${p.brand} ' : ''}${p.name}', maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(12.5, w: w8, h: 1.3)),
          ),
          Text(pk.w, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11.5, w: w7, c: P.mu)),
          const Spacer(),
          Row(children: [
            Expanded(
              child: Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 3, children: [
                Text('₹${rupee(pk.price)}', style: pop(14)),
                if (o != null) Text('₹${rupee(o.mrp)}', style: ts(11, c: P.mu, deco: TextDecoration.lineThrough)),
              ]),
            ),
            HxBtn(p, pi),
          ]),
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
    final style = ts(13.5, w: w7, c: const Color(0xFF7A4B00));
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
