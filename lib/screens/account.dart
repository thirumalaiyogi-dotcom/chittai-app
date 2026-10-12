// சிட்டை — கணக்கு, விருப்பமானவை, உதவி மையம், சிட்டை பற்றி / தனியுரிமை / விதிமுறைகள்
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../nav.dart';
import '../orders.dart';
import '../state.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets.dart';
import 'location.dart';
import 'notifs.dart';
import 'orders.dart';
import 'stories.dart';

// HTML .ov: கீழ் பட்டைக்கு மேலே திறக்கும்; எந்த tab-உம் ஒளிராது (navSync on='')
Future<T?> pushFull<T>(Widget w) => Nav.push<T>(w, hl: '');

AppBar plainBar(BuildContext context, String title, {List<Widget>? actions}) => AppBar(
      backgroundColor: P.card,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(icon: Icon(Icons.arrow_back, color: P.text), onPressed: () => Navigator.of(context).maybePop()),
      title: Text(title, style: ts(18, w: w8)),
      actions: actions,
    );

Future<void> shareApp() async {
  try {
    await Share.share(appShareText, subject: 'சிட்டை');
  } catch (_) {
    openUrl('https://wa.me/?text=${Uri.encodeComponent(appShareText)}');
  }
}

// ═══ கணக்கு ═══
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _editing = false; // HTML profEditing

  static void _dark(bool v) {
    AppState.I.setDark(v);
    WidgetsBinding.instance.addPostFrameCallback((_) => rebuildAllWidgets());
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (_editing) {
      return Scaffold(
        backgroundColor: P.bg,
        appBar: plainBar(context, 'என் விவரங்கள்'),
        body: _ProfileForm(onDone: () => setState(() => _editing = false)),
      );
    }
    final p = s.profGet();
    final raw = s.profRaw();
    final nOrd = s.ordLocal().length, nFav = s.favIds.length;
    final nm = p != null ? js(p['nm']) : '';
    final ini = nm.trim().characters.take(2).join();
    final ph = p != null ? '+91 ${js(p['ph']).substring(0, 5)} ${js(p['ph']).substring(5)}' : '';
    final area = js(raw['area']).isNotEmpty ? js(raw['area']) : (raw['lat'] != null ? 'இடம் சேமிக்கப்பட்டது' : 'சேர்க்கவில்லை');
    Widget row(IconData ic, String t, {String sub = '', VoidCallback? onTap, Widget? right, bool red = false}) => InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: red ? const Color(0xFFFEE2E2) : P.gc, borderRadius: BorderRadius.circular(11)),
                child: Icon(ic, size: 20, color: red ? const Color(0xFFDC2626) : P.g2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t, style: ts(15, w: w7, c: red ? const Color(0xFFDC2626) : P.text)),
                  if (sub.isNotEmpty) Text(sub, style: ts(12, c: P.mu)),
                ]),
              ),
              right ?? Icon(Icons.chevron_right, color: P.mu),
            ]),
          ),
        );
    Widget group(List<Widget> k) => Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          decoration: BoxDecoration(color: P.card, border: Border.all(color: P.bd), borderRadius: BorderRadius.circular(18)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < k.length; i++) ...[if (i > 0) Divider(height: 1, color: P.bd, indent: 66), k[i]],
          ]),
        );
    Widget quick(IconData ic, String big, String small, VoidCallback f) => Expanded(
          child: InkWell(
            onTap: f,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(color: P.card, border: Border.all(color: P.bd), borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Icon(ic, color: P.g2, size: 22),
                const SizedBox(height: 4),
                Text(big, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(15, w: w8)),
                Text(small, style: ts(11.5, c: P.mu)),
              ]),
            ),
          ),
        );
    return Scaffold(
      backgroundColor: P.bg,
      appBar: plainBar(context, 'கணக்கு'),
      body: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        Container(
          margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: kHeroGrad, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0x33FFFFFF),
              child: ini.isNotEmpty ? Text(ini, style: ts(20, w: w8, c: Colors.white)) : const Icon(Icons.person, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('வணக்கம் 👋', style: ts(12.5, c: const Color(0xDDFFFFFF))),
                if (nm.isNotEmpty) Text(nm, style: ts(18, w: w8, c: Colors.white)),
                Text(p != null ? ph : 'உங்கள் விவரங்களைச் சேர்க்கவும்', style: ts(13, w: w6, c: const Color(0xEEFFFFFF))),
              ]),
            ),
            TextButton(
              style: TextButton.styleFrom(backgroundColor: const Color(0x33FFFFFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => setState(() => _editing = true),
              child: Text(p != null ? '✏️ மாற்று' : '+ சேர்', style: ts(13, w: w8, c: Colors.white)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            quick(Icons.receipt_long_outlined, '$nOrd', 'ஆர்டர்கள்', () {
              Navigator.of(context).pop();
              Nav.go('orders');
            }),
            const SizedBox(width: 8),
            quick(Icons.favorite_border, '$nFav', 'விருப்பங்கள்', () {
              // HTML navGo('fav'): கணக்கை மூடி விருப்பங்கள்
              Nav.popInnerToRoot();
              pushFull(const FavScreen());
            }),
            const SizedBox(width: 8),
            quick(Icons.location_on_outlined, area, 'முகவரி', () => showLocationSheet()),
          ]),
        ),
        group([
          row(Icons.notifications_none, 'அறிவிப்புகள்', sub: 'ஆர்டர் நிலை மாறியதும் தெரிவிக்க', onTap: () => pushFull(const NotifScreen())),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(color: P.gc, borderRadius: BorderRadius.circular(11)), child: Icon(Icons.text_fields, size: 20, color: P.g2)),
              const SizedBox(width: 12),
              Expanded(child: Text('எழுத்து அளவு', style: ts(15, w: w7))),
              for (final x in const [
                ['1', 'சிறிது'],
                ['2', 'நடுத்தரம்'],
                ['3', 'பெரிது']
              ])
                GestureDetector(
                  onTap: () => s.setFs(x[0]),
                  child: Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(color: s.fs == x[0] ? P.g : P.card2, border: Border.all(color: s.fs == x[0] ? P.g : P.bd), borderRadius: BorderRadius.circular(10)),
                    child: Text(x[1], style: TextStyle(fontSize: 10 + int.parse(x[0]) * 1.5, fontWeight: w8, color: s.fs == x[0] ? Colors.white : P.mu2)),
                  ),
                ),
            ]),
          ),
          row(Icons.dark_mode_outlined, 'இரவு நிறம்', sub: s.dark ? 'ஆன்' : 'ஆஃப்', onTap: () => _dark(!s.dark), right: Switch(value: s.dark, activeTrackColor: P.g, onChanged: _dark)),
        ]),
        group([
          row(Icons.help_outline, 'உதவி & ஆதரவு', sub: 'சிட்டை WhatsApp', onTap: () => pushFull(const HelpScreen())),
          row(Icons.share_outlined, 'நண்பர்களுக்குப் பகிருங்கள்', onTap: shareApp),
        ]),
        group([
          row(Icons.info_outline, 'சிட்டை பற்றி', onTap: () => pushFull(const InfoScreen(page: 'about'))),
          row(Icons.lock_outline, 'தனியுரிமைக் கொள்கை', onTap: () => pushFull(const InfoScreen(page: 'privacy'))),
          row(Icons.description_outlined, 'விதிமுறைகள்', onTap: () => pushFull(const InfoScreen(page: 'terms'))),
        ]),
        if (p != null)
          group([
            row(Icons.delete_outline, 'என் விவரங்களை நீக்கு', red: true, right: const SizedBox.shrink(), onTap: () async {
              final ok = await confirmDialog('பெயர், எண், முகவரி இந்த phone-லிருந்து நீக்கப்படும். சரியா?', danger: true);
              if (!ok) return;
              final o = s.profRaw()
                ..remove('nm')
                ..remove('ph')
                ..remove('ad');
              profPut(o);
              s.ping();
              toast('🗑️ விவரங்கள் நீக்கப்பட்டன');
            }),
          ]),
        Padding(padding: const EdgeInsets.all(18), child: Text(appVersionText, textAlign: TextAlign.center, style: ts(12, c: P.mu))),
      ]),
    );
  }
}

// ═══ விருப்பமானவை (இந்த phone மட்டும்) ═══
class FavScreen extends StatelessWidget {
  const FavScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final list = <Product>[];
    for (var k = s.favIds.length - 1; k >= 0; k--) {
      final p = s.prods.where((x) => x.key == js(s.favIds[k])).first0;
      if (p != null && !p.hidden && p.packs.isNotEmpty) list.add(p);
    }
    return Scaffold(
      backgroundColor: P.bg,
      appBar: plainBar(context, 'விருப்பமானவை'),
      body: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🤍', style: TextStyle(fontSize: 50)),
                  const SizedBox(height: 8),
                  Text('விருப்பமான பொருட்கள் எதுவும் இல்லை', style: ts(16, w: w8)),
                  Text('பொருளின் ♡ ஐத் தட்டினால் இங்கே சேமிக்கப்படும்', textAlign: TextAlign.center, style: ts(13, c: P.mu)),
                ]),
              ),
            )
          : ListView(padding: const EdgeInsets.only(bottom: 30), children: list.map((p) => _FavItem(p)).toList()),
    );
  }
}

class _FavItem extends StatelessWidget {
  final Product p;
  const _FavItem(this.p);
  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final single = p.packs.length == 1;
    final sh = s.shopById(p.shopId);
    final fo = single ? p.packs[0].offer : null, fb = p.bestOffer;
    final q = single ? s.qtyOf(p, 0) : 0;
    final tq = s.totalQtyOf(p);
    Widget act;
    if (single) {
      act = q > 0
          ? QtyStepper(qty: q, height: 32, btnW: 30, font: 14, onMinus: () => CartOps.chg(p, 0, -1), onPlus: () => CartOps.chg(p, 0, 1))
          : _btn('+ சேர்', () => CartOps.add(p, 0));
    } else {
      act = _btn(tq > 0 ? 'Cart-ல் $tq' : 'தேர்வு', () => Nav.openProduct(p));
    }
    return GestureDetector(
      onTap: () => Nav.openProduct(p),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: P.card, border: Border.all(color: P.bd), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(color: P.card2, borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: Img(p.photo, emoji: p.emoji, emojiSize: 32),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (p.brand.isNotEmpty) Text(p.brand.toUpperCase(), style: ts(11, w: w7, c: P.mu2)),
              Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(14.5, w: w8)),
              Text.rich(TextSpan(style: ts(12.5, w: w6, c: P.mu2), children: [
                if (single) ...[
                  TextSpan(text: '${p.packs[0].w.isNotEmpty ? '${p.packs[0].w} · ' : ''}₹${rupee(p.packs[0].price)}'),
                  if (fo != null) TextSpan(text: ' ₹${rupee(fo.mrp)}', style: const TextStyle(decoration: TextDecoration.lineThrough)),
                  if (fo != null) TextSpan(text: ' ${fo.off}% தள்ளுபடி', style: ts(12, w: w8, c: const Color(0xFF16A34A))),
                ] else ...[
                  TextSpan(text: '${p.packs.length} அளவுகள் · ₹${rupee(p.minPrice)} முதல்'),
                  if (fb != null) TextSpan(text: ' ${fb.off}% வரை தள்ளுபடி', style: ts(12, w: w8, c: const Color(0xFF16A34A))),
                ],
              ])),
              if (sh != null) Text('🏪 ${sh.name}', style: ts(11.5, c: P.mu)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            FavButton(p, size: 30),
            const SizedBox(height: 6),
            act,
          ]),
        ]),
      ),
    );
  }

  Widget _btn(String l, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(border: Border.all(color: P.g, width: 1.5), borderRadius: BorderRadius.circular(10)),
          child: Text(l, style: ts(12.5, w: w8, c: P.g2)),
        ),
      );
}

// ═══ உதவி மையம் ═══
class HelpScreen extends StatefulWidget {
  final OrderV? order;
  const HelpScreen({super.key, this.order});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  int _open = -1;

  List<Widget> _deliv(Shop s) {
    final dl = <String>[];
    if (!s.deliveryAvailable) {
      dl.add('🚫 டெலிவரி இல்லை');
    } else {
      dl.add('✅ டெலிவரி உண்டு');
      if (s.etaKnown) dl.add('🚚 ${s.etaText} நிமிடம்');
      for (final t in s.feeText) {
        dl.add('🚚 $t');
      }
    }
    if (jz(s.m['min_order']) > 0) dl.add('குறைந்தபட்ச ஆர்டர்: ₹${rupee(s.m['min_order'])}');
    return dl.map((x) => Text(x, style: ts(13, c: P.mu2))).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final appN = supNum(s.waNum);
    final pr = s.profGet();
    final nm = pr != null ? js(pr['nm']).split(' ')[0] : '';
    OrderV? o = widget.order;
    if (o == null) {
      final l = Orders.I.build();
      if (l.isNotEmpty) o = l.first;
    }
    final shop = s.shopById(s.activeShop);
    String wa(String t) => 'https://wa.me/$appN?text=${Uri.encodeComponent(t)}';
    final faq = <List<dynamic>>[
      [
        Icons.local_shipping_outlined,
        'என் ஆர்டர் எங்கே இருக்கிறது?',
        '"ஆர்டர்கள்" பகுதியில் உங்கள் ஆர்டரை நேரலையாகப் பின்தொடரலாம்: பெறப்பட்டது → உறுதி → பார்சல் ரெடி → புறப்பட்டது → டெலிவரி.\nNotification அனுமதித்திருந்தால், ஒவ்வொரு மாற்றமும் உடனே தெரியும்.',
        'என் ஆர்டர்கள்'
      ],
      [
        Icons.cancel_outlined,
        'ஆர்டரை ரத்து செய்யலாமா?',
        'ஆம் — கடை பார்சல் செய்து முடிக்கும் முன்பு வரை. ஆர்டர் விவரப் பக்கத்தில் "ஆர்டரை ரத்து செய்ய" பட்டனைத் தட்டுங்கள்.\nஅந்தப் பட்டன் தெரியவில்லை என்றால், ஆர்டர் எண்ணுடன் எங்களை WhatsApp-ல் தொடர்பு கொள்ளுங்கள்.',
        'என் ஆர்டர்கள்'
      ],
      [
        Icons.payments_outlined,
        'பணம் எப்படி செலுத்துவது?',
        'பொருள் உங்கள் கைக்கு வந்த பிறகு, டெலிவரி நபரிடம் பணம் செலுத்துங்கள் (Cash on Delivery).\nOnline payment தற்போது இல்லை. முன்பணம் கேட்டு யாராவது அழைத்தால் செலுத்த வேண்டாம்.',
        null
      ],
      [
        Icons.schedule,
        'டெலிவரி கட்டணமும் நேரமும் எவ்வளவு?',
        'ஒவ்வொரு கடைக்கும் தனியாக இருக்கும். கடைப் பக்கத்திலும் கூடையிலும் காட்டப்படும்; குறிப்பிட்ட தொகைக்கு மேல் இலவச டெலிவரி உண்டு.\nகாட்டப்படும் நேரம் மதிப்பீடு மட்டுமே.',
        null
      ],
      [Icons.inventory_2_outlined, 'பொருள் குறைவாக / சேதமாக வந்தால்?', 'டெலிவரி ஆன அன்றே, ஆர்டர் எண் மற்றும் பொருளின் படத்துடன் WhatsApp-ல் அனுப்புங்கள். சரிபார்த்து கடையுடன் பேசி தீர்வு சொல்வோம்.', null],
      [Icons.place_outlined, 'முகவரி / டெலிவரி இடத்தை மாற்றுவது எப்படி?', 'கணக்கு → "மாற்று"-ல் பெயர், மொபைல், முகவரி, map இடம் அனைத்தையும் மாற்றலாம். ஆர்டர் செய்யும் முன் கூடையிலும் மாற்றலாம்.', '👤 என் விவரங்கள்'],
    ];
    final st = o != null && o.cloud ? (kCoSt[o.status]?[0] ?? '') : '';
    return Scaffold(
      backgroundColor: P.bg,
      appBar: plainBar(context, 'உதவி மையம்'),
      body: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        Container(
          margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: kHeroGrad, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('வணக்கம்${nm.isNotEmpty ? ', $nm' : ''} 👋', style: ts(14, w: w7, c: const Color(0xE6FFFFFF))),
            Text('உங்களுக்கு எப்படி உதவலாம்?', style: ts(19, w: w8, c: Colors.white)),
            const SizedBox(height: 14),
            if (appN.isNotEmpty)
              Row(children: [
                Expanded(child: _heroBtn(Icons.chat, 'WhatsApp', 'எங்களுடன் பேசுங்கள்', () => openUrl(wa('வணக்கம், சிட்டை app-ல் உதவி தேவை.')), wa: true)),
                const SizedBox(width: 10),
                Expanded(child: _heroBtn(Icons.call, 'அழைக்க', 'நேரடியாக பேச', () => openUrl('tel:+$appN'))),
              ])
            else
              Text('Support தொடர்பு தற்போது கிடைக்கவில்லை.', style: ts(13, c: Colors.white)),
          ]),
        ),
        if (o != null) ...[
          _sec(widget.order != null ? 'இந்த ஆர்டர்' : 'உங்கள் சமீபத்திய ஆர்டர்'),
          _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: P.gc, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.shopping_bag_outlined, color: P.g2)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o.no, style: ts(14.5, w: w8)),
                  Text('${o.shop.isNotEmpty ? '${o.shop} · ' : ''}₹${rupee(o.tot)}', style: ts(12.5, c: P.mu2)),
                ]),
              ),
            ]),
            if (st.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: P.gc, borderRadius: BorderRadius.circular(10)),
                  child: Text(st, style: ts(12, w: w8, c: P.g2)),
                ),
              ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final id = o!.id;
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    if (o.cloud && id != null) {
                      openTrack(id);
                    } else {
                      Nav.go('orders');
                    }
                  },
                  child: Text(o.cloud && o.id != null ? 'பின்தொடர' : 'விவரம்', style: ts(13, w: w8, c: P.g2)),
                ),
              ),
              if (appN.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                    onPressed: () => openUrl(wa('ஆர்டர் எண்: ${o!.no} பற்றி உதவி தேவை.${o.shop.isNotEmpty ? ' (கடை: ${o.shop})' : ''}')),
                    child: Text('💬 இதைப் பற்றி கேட்க', style: ts(12.5, w: w8, c: Colors.white)),
                  ),
                ),
              ],
            ]),
          ])),
        ],
        _sec('அடிக்கடி கேட்கப்படுபவை'),
        _card(
          Column(children: [
            for (var i = 0; i < faq.length; i++) ...[
              if (i > 0) Divider(height: 1, color: P.bd),
              InkWell(
                onTap: () => setState(() => _open = _open == i ? -1 : i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(children: [
                    Icon(faq[i][0] as IconData, color: P.g2, size: 21),
                    const SizedBox(width: 12),
                    Expanded(child: Text(faq[i][1] as String, style: ts(14, w: w8))),
                    AnimatedRotation(turns: _open == i ? .25 : 0, duration: const Duration(milliseconds: 150), child: Icon(Icons.chevron_right, color: P.mu)),
                  ]),
                ),
              ),
              if (_open == i)
                Padding(
                  padding: const EdgeInsets.fromLTRB(33, 0, 0, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(faq[i][2] as String, style: ts(13.5, c: P.mu2, h: 1.55)),
                    if (i == 3 && shop != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: P.card2, borderRadius: BorderRadius.circular(10)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(shop.name, style: ts(13.5, w: w8)), ..._deliv(shop)]),
                      ),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      if (faq[i][3] != null)
                        OutlinedButton(
                          onPressed: () {
                            if (faq[i][3] == 'என் ஆர்டர்கள்') {
                              Navigator.of(context).popUntil((r) => r.isFirst);
                              Nav.go('orders');
                            } else {
                              showAddressSheet();
                            }
                          },
                          child: Text(faq[i][3] as String, style: ts(13, w: w8, c: P.g2)),
                        ),
                      if (appN.isNotEmpty)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                          onPressed: () => openUrl(wa('${faq[i][1]} — உதவி தேவை.')),
                          child: Text('💬 WhatsApp', style: ts(13, w: w8, c: Colors.white)),
                        ),
                    ]),
                  ]),
                ),
            ],
          ]),
          pad: const EdgeInsets.symmetric(horizontal: 14),
        ),
        _sec('தகவல்'),
        _card(
          Column(children: [
            for (final x in const [
              ['about', 'சிட்டை பற்றி', 'நாங்கள் யார், எப்படி வேலை செய்கிறது'],
              ['privacy', 'தனியுரிமைக் கொள்கை', 'உங்கள் தகவல் எப்படிப் பாதுகாக்கப்படுகிறது'],
              ['terms', 'விதிமுறைகள்', 'ஆர்டர், டெலிவரி, பணம், ரத்து'],
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(x[1], style: ts(14.5, w: w8)),
                subtitle: Text(x[2], style: ts(12, c: P.mu)),
                trailing: Icon(Icons.chevron_right, color: P.mu),
                onTap: () => pushFull(InfoScreen(page: x[0])),
              ),
          ]),
          pad: const EdgeInsets.symmetric(horizontal: 14),
        ),
        const _Foot(),
      ]),
    );
  }

  Widget _heroBtn(IconData ic, String b, String s, VoidCallback f, {bool wa = false}) => GestureDetector(
        onTap: f,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: wa ? const Color(0xFF25D366) : const Color(0xFF075E54), shape: BoxShape.circle),
              child: Icon(ic, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b, style: ts(14, w: w8, c: const Color(0xFF17201D))),
                Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11, c: const Color(0xFF64706C))),
              ]),
            ),
          ]),
        ),
      );
}

Widget _sec(String t) => Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 8), child: Text(t, style: ts(14, w: w8, c: P.mu2)));

Widget _card(Widget c, {EdgeInsets pad = const EdgeInsets.all(14)}) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: pad,
      decoration: BoxDecoration(color: P.card, border: Border.all(color: P.bd), borderRadius: BorderRadius.circular(18)),
      child: c,
    );

class _Foot extends StatelessWidget {
  const _Foot();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(children: [
          RichText(text: TextSpan(style: pop(22, c: P.g2), children: const [TextSpan(text: 'சிட்டை'), TextSpan(text: '.', style: TextStyle(color: Color(0xFF00A884)))])),
          const SizedBox(height: 4),
          Text('உங்கள் ஊர் கடைகள் — உங்கள் வீட்டு வாசலில்', style: ts(12.5, c: P.mu2)),
          Text(appVersionText, style: ts(11.5, c: P.mu)),
        ]),
      );
}

// ═══ சிட்டை பற்றி / தனியுரிமை / விதிமுறைகள் ═══
class InfoScreen extends StatefulWidget {
  final String page;
  const InfoScreen({super.key, required this.page});
  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  late String _p = widget.page;
  static const _upd = 'கடைசியாகப் புதுப்பித்தது: அக்டோபர் 2026';
  static const _titles = {'about': 'சிட்டை பற்றி', 'privacy': 'தனியுரிமைக் கொள்கை', 'terms': 'விதிமுறைகள்'};

  Widget _li(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('•  ', style: ts(14, w: w8, c: P.g2)),
          Expanded(child: Text(t, style: ts(13.5, c: P.mu2, h: 1.5))),
        ]),
      );

  Widget _secN(int n, String t, List<Widget> body) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 13, backgroundColor: P.gc, child: Text('$n', style: ts(12, w: w8, c: P.g2))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: ts(15, w: w8)), const SizedBox(height: 6), ...body])),
        ]),
      );

  Widget _p2(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: ts(13.5, c: P.mu2, h: 1.55)));

  Widget _hero(IconData ic, String t) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: P.gc, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(ic, color: P.g2, size: 30),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: ts(16, w: w8)), Text(_upd, style: ts(12, c: P.mu))])),
        ]),
      );

  List<Widget> _about() {
    const steps = [
      [Icons.storefront_outlined, 'கடையைத் தேர்ந்தெடுங்கள்', 'உங்கள் அருகிலுள்ள மளிகை, காய்கறி, பழம், உணவகம்…'],
      [Icons.shopping_bag_outlined, 'கூடையில் சேருங்கள்', 'விலை, அளவு எல்லாம் தெளிவாக'],
      [Icons.check_circle_outline, 'ஆர்டர் செய்யுங்கள்', 'சிட்டை உறுதி செய்து கடைக்கு அனுப்பும்'],
      [Icons.local_shipping_outlined, 'வீட்டு வாசலில் பெறுங்கள்', 'நேரலையாகப் பின்தொடருங்கள்; வந்ததும் பணம்'],
    ];
    const feats = [
      [Icons.place_outlined, 'அருகிலுள்ள கடைகள்', 'உங்கள் ஊர் கடைகள் ஒரே app-ல்'],
      [Icons.local_shipping_outlined, 'நேரலை tracking', 'ஆர்டர் எங்கே என்று தெரியும்'],
      [Icons.payments_outlined, 'Cash on Delivery', 'பொருள் வந்த பிறகு பணம்'],
      [Icons.notifications_none, 'உடனடி அறிவிப்பு', 'ஒவ்வொரு நிலையிலும் notification'],
    ];
    return [
      Center(child: RichText(text: TextSpan(style: pop(30, c: P.g2), children: const [TextSpan(text: 'சிட்டை'), TextSpan(text: '.', style: TextStyle(color: Color(0xFF00A884)))]))),
      Center(child: Text('உங்கள் ஊர் கடைகள் — உங்கள் வீட்டு வாசலில்', style: ts(13, c: P.mu2))),
      const SizedBox(height: 14),
      _p2('சிட்டை உங்கள் பகுதியில் உள்ள நம்பிக்கையான கடைகளை ஒரே இடத்தில் இணைக்கிறது. நீங்கள் ஆர்டர் செய்தால், கடை பார்சல் செய்து, எங்கள் டெலிவரி நபர் உங்கள் வீட்டுக்குக் கொண்டு வருவார்.'),
      const SizedBox(height: 8),
      Text('எப்படி வேலை செய்கிறது?', style: ts(15, w: w8)),
      const SizedBox(height: 8),
      for (var i = 0; i < steps.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(backgroundColor: P.gc, child: Icon(steps[i][0] as IconData, color: P.g2)),
          title: Text('${i + 1}. ${steps[i][1]}', style: ts(14, w: w8)),
          subtitle: Text(steps[i][2] as String, style: ts(12.5, c: P.mu)),
        ),
      const SizedBox(height: 8),
      Text('ஏன் சிட்டை?', style: ts(15, w: w8)),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.25,
        children: [
          for (final f in feats)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: P.card, border: Border.all(color: P.bd), borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(f[0] as IconData, color: P.g2),
                const SizedBox(height: 6),
                Text(f[1] as String, style: ts(13.5, w: w8)),
                Text(f[2] as String, style: ts(11.5, c: P.mu)),
              ]),
            ),
        ],
      ),
      const SizedBox(height: 12),
      _p2('பொருட்கள், விலை, இருப்பு ஆகியவை அந்தந்த கடையால் வழங்கப்படுபவை.'),
    ];
  }

  List<Widget> _privacy() => [
        _hero(Icons.shield_outlined, 'உங்கள் தகவல் பாதுகாப்பானது'),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: P.card, border: Border.all(color: P.bd), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('சுருக்கமாக', style: ts(14, w: w8)),
            for (final x in const ['ஆர்டர் டெலிவரிக்குத் தேவையானது மட்டுமே கேட்கிறோம்', 'உங்கள் தகவலை யாருக்கும் விற்பதில்லை; விளம்பரம் இல்லை', 'எப்போது வேண்டுமானாலும் நீக்கக் கேட்கலாம்'])
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [Icon(Icons.check, size: 16, color: P.g2), const SizedBox(width: 6), Expanded(child: Text(x, style: ts(13, c: P.mu2)))]),
              ),
          ]),
        ),
        _secN(1, 'நாங்கள் பெறும் தகவல்', [
          _li('பெயர், மொபைல் எண், முகவரி'),
          _li('டெலிவரி இடம் — map-ல் நீங்கள் குறிக்கும் pin'),
          _li('ஆர்டர் விவரம் — பொருட்கள், அளவு, தொகை, குறிப்பு'),
          _li('Notification-க்கான அனுமதி (நீங்கள் அனுமதித்தால் மட்டும்)'),
        ]),
        _secN(2, 'எதற்காக', [
          _li('ஆர்டரை உறுதி செய்து டெலிவரி செய்ய'),
          _li('உங்கள் இடம் டெலிவரி பகுதிக்குள் உள்ளதா என்று பார்க்க'),
          _li('ஆர்டர் நிலையை notification மூலம் தெரிவிக்க'),
          _li('அடுத்த முறை விவரங்களைத் தானாக நிரப்ப'),
        ]),
        _secN(3, 'யார் பார்க்க முடியும்', [
          _li('சிட்டை நிர்வாகம் — ஆர்டரை உறுதி செய்ய'),
          _li('கடை — உங்கள் பெயரும் பொருட்களும் மட்டும்; மொபைல், முகவரி காட்டப்படாது'),
          _li('டெலிவரி நபர் — உங்கள் ஆர்டருக்கு மட்டும்: பெயர், மொபைல், முகவரி, இடம்'),
        ]),
        _secN(4, 'எங்கே சேமிக்கப்படுகிறது', [_p2('ஆர்டர் விவரங்கள் பாதுகாப்பான cloud server-ல் (Supabase) சேமிக்கப்படுகின்றன. உங்கள் விவரங்கள், கூடை, விருப்பங்கள் இந்த phone-லும் சேமிக்கப்படும்.')]),
        _secN(5, 'நாங்கள் ஒருபோதும் கேட்காதவை', [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final x in const ['Card எண்', 'CVV', 'UPI PIN', 'வங்கி / UPI OTP', 'Aadhaar', 'PAN', 'Password'])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
                child: Text(x, style: ts(12, w: w8, c: const Color(0xFFB91C1C))),
              ),
          ]),
          const SizedBox(height: 8),
          _p2('ஆப்பில் தெரியும் 4 இலக்க டெலிவரி OTP-ஐ மட்டும், பார்சலைக் கையில் வாங்கி பணம் கொடுத்த பிறகு delivery நண்பரிடம் சொல்லலாம்.'),
          _p2('சிட்டை பெயரில் யாராவது இவற்றைக் கேட்டால் கொடுக்க வேண்டாம்.'),
        ]),
        _secN(6, 'உங்கள் உரிமைகள்', [
          _li('கணக்கு பகுதியில் உங்கள் தகவலை மாற்றலாம் / நீக்கலாம்'),
          _li('Location, notification அனுமதியை phone settings-ல் நிறுத்தலாம்'),
          _li('Server-ல் உள்ள ஆர்டர் விவரங்களை நீக்க, உங்கள் மொபைல் எண்ணுடன் கேளுங்கள் — 30 நாட்களுக்குள் நீக்கப்படும் (சட்டப்படி வைக்க வேண்டிய கணக்கு விவரங்கள் தவிர)'),
        ]),
        _secN(7, 'மற்றவை', [_p2('Map-க்கு OpenStreetMap, எழுத்துருக்களுக்கு Google Fonts பயன்படுத்தப்படுகிறது. விளம்பர / tracking கருவிகள் எதுவும் இல்லை.')]),
      ];

  List<Widget> _terms() => [
        _hero(Icons.description_outlined, 'பயன்பாட்டு விதிமுறைகள்'),
        _secN(1, 'பயன்பாடு', [_p2('சிட்டை மூலம் உங்கள் பகுதிக் கடைகளில் ஆர்டர் செய்யலாம். சரியான பெயர், மொபைல் எண், முகவரி, டெலிவரி இடம் கொடுப்பது உங்கள் பொறுப்பு.')]),
        _secN(2, 'ஆர்டர் எப்படி நடக்கிறது', [
          _li('நீங்கள் ஆர்டர் செய்ததும் சிட்டை அதைச் சரிபார்த்து உறுதி செய்யும்'),
          _li('கடை பொருட்களைப் பார்சல் செய்யும்'),
          _li('டெலிவரி நபர் உங்களிடம் கொண்டு வருவார்'),
          _li('பொருள் இருப்பு இல்லையெனில் ஆர்டர் மாற்றப்படலாம் அல்லது ரத்தாகலாம்'),
        ]),
        _secN(3, 'ரத்து செய்தல்', [_p2('கடை பார்சல் செய்யத் தொடங்கும் முன்பு வரை, ஆர்டர் விவரப் பக்கத்திலிருந்து நீங்களே ரத்து செய்யலாம். அதன் பிறகு Support-ஐத் தொடர்பு கொள்ளுங்கள்.')]),
        _secN(4, 'விலை & பொருட்கள்', [_p2('பொருட்கள், படங்கள், விலை, சலுகைகள் கடை வழங்குபவை; மாறலாம். ஆர்டர் செய்யும் நேரத்தில் server-ல் உள்ள விலையே இறுதியானது.')]),
        _secN(5, 'டெலிவரி', [_p2('ஒவ்வொரு கடைக்கும் டெலிவரி பகுதி, கட்டணம், குறைந்தபட்ச ஆர்டர் தனியாக உண்டு. பகுதிக்கு வெளியே உள்ள இடத்துக்கு ஆர்டர் ஏற்கப்படாது. காட்டப்படும் நேரம் மதிப்பீடு மட்டுமே.')]),
        _secN(6, 'பணம் செலுத்துதல்', [_p2('தற்போது Cash on Delivery மட்டும் — பொருள் பெறும்போது டெலிவரி நபரிடம் செலுத்துங்கள்.')]),
        _secN(7, 'குறைபாடு / Return', [_p2('பொருள் குறைவாகவோ சேதமாகவோ வந்தால், அன்றே ஆர்டர் எண் மற்றும் படத்துடன் Support-க்குத் தெரிவியுங்கள். கடையுடன் பேசி தீர்வு காணப்படும்.')]),
        _secN(8, 'மாற்றங்கள்', [_p2('App மேம்படுத்தப்படும்போது இந்த விதிமுறைகள் மாறலாம். தொடர்ந்து பயன்படுத்துவது புதிய விதிமுறைகளை ஏற்பதாகும்.')]),
      ];

  @override
  Widget build(BuildContext context) {
    final appN = supNum(AppState.I.waNum);
    final keys = ['about', 'privacy', 'terms'];
    const lbl = {'about': 'பற்றி', 'privacy': 'தனியுரிமை', 'terms': 'விதிமுறைகள்'};
    final body = _p == 'privacy' ? _privacy() : (_p == 'terms' ? _terms() : _about());
    return Scaffold(
      backgroundColor: P.bg,
      appBar: plainBar(context, _titles[_p]!),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: P.card3, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            for (final k in keys)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _p = k),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: _p == k ? P.card : Colors.transparent, borderRadius: BorderRadius.circular(11)),
                    child: Text(lbl[k]!, textAlign: TextAlign.center, style: ts(13.5, w: w8, c: _p == k ? P.g2 : P.mu2)),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        ...body,
        if (appN.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: P.card, border: Border.all(color: P.bd), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('கேள்விகள் இருக்கிறதா?', style: ts(14.5, w: w8)),
                  Text('எங்கள் குழு உதவத் தயார்', style: ts(12, c: P.mu)),
                ]),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                onPressed: () => openUrl('https://wa.me/$appN?text=${Uri.encodeComponent('வணக்கம், சிட்டை app பற்றி ஒரு கேள்வி.')}'),
                child: Text('💬 WhatsApp', style: ts(13, w: w8, c: Colors.white)),
              ),
            ]),
          ),
        const _Foot(),
      ]),
    );
  }
}

// app-ன் முதல் திறப்பு நேரம் (popups-க்கு)
void markFirstRunSeen() => Store.setStr(K.firstRun, '${DateTime.now().millisecondsSinceEpoch}');


// ═══ என் விவரங்கள் (HTML renderProfile + profSubmit) — வரைபடம் இல்லை ═══
class _ProfileForm extends StatefulWidget {
  final VoidCallback onDone;
  const _ProfileForm({required this.onDone});
  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final Map<String, dynamic> _p = AppState.I.profRaw();
  late final _nm = TextEditingController(text: js(_p['nm']));
  late final _ph = TextEditingController(text: js(_p['ph']));
  final Map<String, TextEditingController> _ad = {};
  final Map<String, String> _err = {};

  @override
  void initState() {
    super.initState();
    final pa = adPartsOf(_p);
    for (final f in kAdF) {
      _ad[f.k] = TextEditingController(text: pa[f.k] ?? '');
    }
  }

  @override
  void dispose() {
    _nm.dispose();
    _ph.dispose();
    for (final c in _ad.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final nm = _nm.text.trim(), ph = _ph.text.trim();
    final a = {for (final f in kAdF) f.k: _ad[f.k]!.text.replaceAll(RegExp(r'\s+'), ' ').trim()};
    final e = <String, String>{};
    if (nm.isEmpty) e['nm'] = 'பெயரை உள்ளிடுங்கள்';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(ph)) e['ph'] = ph.isEmpty ? 'மொபைல் எண்ணை உள்ளிடுங்கள்' : 'சரியான 10 இலக்க மொபைல் எண் உள்ளிடுங்கள்';
    e.addAll(adCheck(a));
    setState(() {
      _err
        ..clear()
        ..addAll(e);
    });
    if (e.isNotEmpty) return;
    // profSave + adStoreParts: மற்ற விவரங்கள் (இடம், lat/lng, adHint) அப்படியே இருக்கும்
    final o = AppState.I.profRaw();
    o['nm'] = nm;
    o['ph'] = ph;
    o['ad'] = adCompose(a).trim();
    o['adp'] = a;
    profPut(o);
    AppState.I.ping();
    widget.onDone();
    toast('✅ விவரங்கள் சேமிக்கப்பட்டன');
  }

  InputDecoration _dec(String hint, String key) => InputDecoration(
        hintText: hint,
        hintStyle: ts(14, c: P.mu),
        isDense: true,
        filled: true,
        fillColor: P.card2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: P.bd)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _err.containsKey(key) ? const Color(0xFFDC2626) : P.bd)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: P.g)),
      );

  Widget _errTxt(String key) => _err[key] == null
      ? const SizedBox(height: 12)
      : Padding(padding: const EdgeInsets.only(top: 4, bottom: 8), child: Text(_err[key]!, style: ts(12, w: w7, c: const Color(0xFFDC2626))));

  Widget _lbl(String t, {bool req = true}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(TextSpan(style: ts(13, w: w8, c: P.mu2), children: [
          TextSpan(text: t),
          req ? const TextSpan(text: ' *', style: TextStyle(color: Color(0xFFDC2626))) : TextSpan(text: ' (விருப்பம்)', style: ts(11.5, c: P.mu)),
        ])),
      );

  Widget _adf(AdField f) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _lbl(f.l, req: f.req),
        TextField(
          controller: _ad[f.k],
          keyboardType: f.num ? TextInputType.number : TextInputType.text,
          inputFormatters: [if (f.num) FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(f.num ? 6 : 80)],
          onChanged: (_) {
            if (_err.containsKey(f.k)) setState(() => _err.remove(f.k));
          },
          style: ts(15, w: w6),
          decoration: _dec(f.ph, f.k),
        ),
        _err[f.k] == null ? const SizedBox(height: 11) : Padding(padding: const EdgeInsets.only(top: 3, bottom: 8), child: Text('⚠️ ${_err[f.k]}', style: ts(12, w: w7, c: const Color(0xFFDC2626)))),
      ]);

  @override
  Widget build(BuildContext context) {
    AdField f(String k) => kAdF.firstWhere((x) => x.k == k);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
      _lbl('பெயர்'),
      TextField(controller: _nm, style: ts(15, w: w6), decoration: _dec('உங்கள் பெயர்', 'nm')),
      _errTxt('nm'),
      _lbl('மொபைல் எண்'),
      TextField(
        controller: _ph,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
        style: ts(15, w: w6),
        decoration: _dec('9XXXXXXXXX', 'ph'),
      ),
      _errTxt('ph'),
      _lbl('வீட்டு முகவரி'),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _adf(f('door'))),
        const SizedBox(width: 10),
        Expanded(child: _adf(f('pin'))),
      ]),
      _adf(f('street')),
      _adf(f('village')),
      _adf(f('land')),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text('🛵 "அடையாளம்" சரியாக இருந்தால் டெலிவரி நபர் வீட்டை எளிதில் கண்டுபிடிப்பார்.', style: ts(11.5, c: P.mu, h: 1.5)),
      ),
      GreenButton('💾 சேமிக்க', onTap: _submit),
      const SizedBox(height: 10),
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: P.card2,
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: P.bd),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: widget.onDone,
        child: Text('ரத்து', style: ts(13, w: w8, c: P.mu2)),
      ),
      const SizedBox(height: 12),
      Text('🔒 இந்த விவரங்கள் இந்த phone-ல் மட்டும் சேமிக்கப்படும். ஆர்டர் செய்யும்போது தானாக நிரப்பப்படும்.', style: ts(12, c: P.mu)),
    ]);
  }
}
