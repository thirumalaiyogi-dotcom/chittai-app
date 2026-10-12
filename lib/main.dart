// சிட்டை — வாடிக்கையாளர் app (Flutter). தொடக்கம், splash, கீழ் பட்டை, tab-கள்.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'nav.dart';
import 'screens/cart.dart';
import 'orders.dart';
import 'push.dart';
import 'screens/home.dart';
import 'screens/location.dart';
import 'screens/orders.dart';
import 'screens/stories.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'screens/shops.dart';
import 'state.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.init();
  AppState.I.loadLocal();
  Popups.firstRun; // முதல் திறப்பா என்று படித்த பிறகு குறி
  Popups.markRun();
  runApp(ChangeNotifierProvider<AppState>.value(value: AppState.I, child: const ChittaiApp()));
  unawaited(AppState.I.runCloudLoad());
}

class ChittaiApp extends StatelessWidget {
  const ChittaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.select<AppState, bool>((s) => s.dark);
    final scale = context.select<AppState, double>((s) => s.textScale);
    return MaterialApp(
      title: 'சிட்டை',
      debugShowCheckedModeBanner: false,
      navigatorKey: Nav.root,
      theme: buildTheme(dark),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Boot(),
    );
  }
}

// ═══ Splash: scooter ஓடி வருகிறது → "சிட்டை." → app ═══
class Boot extends StatefulWidget {
  const Boot({super.key});
  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> with TickerProviderStateMixin {
  bool _done = false, _out = false;
  final DateTime _t0 = DateTime.now();
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  late final AnimationController _exit = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  Timer? _max;

  @override
  void initState() {
    super.initState();
    _max = Timer(const Duration(milliseconds: 4500), _end);
    _waitReady();
  }

  Future<void> _waitReady() async {
    // தரவு phone-ல் இருந்தால் உடனே; இல்லையெனில் cloud வரும் வரை (அதிகபட்சம் 4.5 வினாடி)
    while (mounted && AppState.I.cloudLoading && !AppState.I.shopsCached) {
      await Future.delayed(const Duration(milliseconds: 150));
    }
    final left = 2100 - DateTime.now().difference(_t0).inMilliseconds;
    if (left > 0) await Future.delayed(Duration(milliseconds: left));
    _end();
  }

  void _end() {
    if (_out || !mounted) return;
    _out = true;
    _max?.cancel();
    _exit.forward().then((_) {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _in.dispose();
    _loop.dispose();
    _exit.dispose();
    _max?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppState.I.dark;
    final w = MediaQuery.of(context).size.width;
    return Stack(children: [
      const Shell(),
      if (!_done)
        GestureDetector(
        onTap: () {
          if (DateTime.now().difference(_t0).inMilliseconds > 500) _end();
        },
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedBuilder(
          animation: Listenable.merge([_in, _loop, _exit]),
          builder: (_, __) {
            final t = _in.value * 1800; // ms
            double seg(double a, double d) => ((t - a) / d).clamp(0.0, 1.0).toDouble();
            final ride = Curves.easeOutBack.transform(seg(100, 950));
            final ring = Curves.elasticOut.transform(seg(750, 600));
            final name = Curves.easeOut.transform(seg(1050, 500));
            final tag = Curves.easeOut.transform(seg(1300, 500));
            final dots = seg(1500, 300);
            final off = Curves.easeIn.transform(_exit.value);
            final bob = (_loop.value < .5 ? _loop.value : 1 - _loop.value) * 6;
            return Opacity(
              opacity: (1 - (off - .4).clamp(0.0, 1.0) / .6).clamp(0.0, 1.0).toDouble(),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -.2),
                    radius: 1.2,
                    colors: dark ? const [Color(0xFF1F2C34), Color(0xFF111B21)] : const [Colors.white, Color(0xFFEAF8F3), Color(0xFFD6F1E8)],
                  ),
                ),
                child: Stack(children: [
                  Positioned(top: -90, right: -90, child: _blob(260, dark)),
                  Positioned(bottom: -80, left: -80, child: _blob(220, dark)),
                  Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        height: 190,
                        width: w,
                        child: Stack(alignment: Alignment.center, children: [
                          Transform.scale(
                            scale: ring,
                            child: Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                color: dark ? const Color(0xFFE9F7F2) : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(color: Color(0x2E007A63), blurRadius: 40, offset: Offset(0, 18)),
                                  BoxShadow(color: Color(0x8CFFFFFF), spreadRadius: 10),
                                ],
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(-w * 1.2 * (1 - ride) + w * 1.3 * off, -bob),
                            child: const Text('🛵', style: TextStyle(fontSize: 92)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 18),
                      Opacity(
                        opacity: name,
                        child: Transform.translate(
                          offset: Offset(0, 16 * (1 - name)),
                          child: RichText(
                            text: TextSpan(style: pop(40, c: dark ? const Color(0xFFE9EDEF) : const Color(0xFF075E54)), children: const [
                              TextSpan(text: 'சிட்டை'),
                              TextSpan(text: '.', style: TextStyle(color: Color(0xFF00A884))),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Opacity(
                        opacity: tag,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - tag)),
                          child: Text('உங்கள் ஊர் கடைகள், உங்கள் கையில்',
                              textAlign: TextAlign.center, style: ts(14, w: w7, c: dark ? const Color(0xFFAEBAC1) : const Color(0xFF4C635C))),
                        ),
                      ),
                    ]),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 64 + MediaQuery.of(context).padding.bottom,
                    child: Opacity(
                      opacity: dots,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        for (var i = 0; i < 3; i++)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3.5),
                            width: 8,
                            height: 8,
                            transform: Matrix4.translationValues(0, -4 * _wave(_loop.value - i * .15), 0),
                            decoration: const BoxDecoration(color: Color(0xFF00A884), shape: BoxShape.circle),
                          ),
                      ]),
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
        ),
      ),
    ]);
  }

  double _wave(double v) {
    final x = v - v.floorToDouble();
    return x < .5 ? x * 2 : (1 - x) * 2;
  }

  Widget _blob(double s, bool dark) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(shape: BoxShape.circle, color: (dark ? const Color(0xFF0B3D34) : const Color(0xFFBFE9DA)).withValues(alpha: .55)),
      );
}

// ═══ கீழ் பட்டை + tab-கள் ═══
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _InnerObserver extends NavigatorObserver {
  final List<String?> _names = [];
  void _sync() {
    Nav.depth.value = _names.length > 1 ? _names.length - 1 : 0;
    Nav.innerHl.value = _names.length > 1 ? _names.last : null;
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    _names.add(route.settings.name);
    _sync();
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (_names.isNotEmpty) _names.removeLast();
    _sync();
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    if (_names.isNotEmpty) _names.removeLast();
    _sync();
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (_names.isNotEmpty) _names.removeLast();
    _names.add(newRoute?.settings.name);
    _sync();
  }
}

class _ShellState extends State<Shell> {
  final _obs = _InnerObserver();

  @override
  void initState() {
    super.initState();
    // முதல் முறை: "டெலிவரி இடம் எங்கே?" (இடம் உறுதி செய்யும் வரை)
    Future.delayed(const Duration(milliseconds: 2900), () {
      if (!mounted) return;
      if (AppState.I.profRaw()['lat'] == null) showLocationSheet();
    });
    // ஆர்டர் badge
    if (AppState.I.ordLocal().isNotEmpty) Orders.I.fetch();
    // 🔔 Firebase push (அமைக்கப்பட்டிருந்தால் மட்டும்)
    Push.init().then((_) => Push.linkRecent());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Nav.back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: P.card,
          systemNavigationBarIconBrightness: AppState.I.dark ? Brightness.light : Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: P.bg,
          body: Stack(children: [
            Navigator(
              key: Nav.inner,
              observers: [_obs],
              onGenerateInitialRoutes: (_, __) => [MaterialPageRoute(builder: (_) => const TabRoot(), settings: const RouteSettings(name: 'root'))],
            ),
            const Positioned(left: 0, right: 0, bottom: 0, child: NetBanner()),
          ]),
          bottomNavigationBar: const BottomNav(),
        ),
      ),
    );
  }
}

class TabRoot extends StatelessWidget {
  const TabRoot({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: Nav.tab,
      builder: (_, t, __) {
        switch (t) {
          case 'shops':
            return const ShopsTab();
          case 'orders':
            return const OrdersScreen();
          case 'cart':
            return const CartScreen();
          default:
            return const HomeScreen();
        }
      },
    );
  }
}

class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final n = s.cartCount;
    final amt = s.cartAmount;
    return AnimatedBuilder(
      animation: Listenable.merge([Nav.tab, Nav.innerHl, Orders.I]),
      builder: (_, __) {
        final on = Nav.innerHl.value ?? Nav.tab.value;
        Widget item(String k, IconData ic, IconData icOn, String lb, {int badge = 0, bool cartLb = false}) {
          final a = on == k;
          final col = a ? P.g2 : const Color(0xFF8A9592);
          return Expanded(
            child: InkWell(
              onTap: () => Nav.go(k),
              child: Stack(alignment: Alignment.center, children: [
                if (a) Positioned(top: 0, left: 22, right: 22, child: Container(height: 3.5, decoration: BoxDecoration(color: P.g, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4))))),
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Stack(clipBehavior: Clip.none, children: [
                    Icon(a ? icOn : ic, color: col, size: 25),
                    if (badge > 0)
                      Positioned(
                        right: -9,
                        top: -5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          constraints: const BoxConstraints(minWidth: 18),
                          decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(10), border: Border.all(color: P.card, width: 1.5)),
                          child: Text(badge > 99 ? '99+' : '$badge', textAlign: TextAlign.center, style: ts(10.5, w: w8, c: Colors.white)),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 3),
                  cartLb && n > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(color: P.g, borderRadius: BorderRadius.circular(10)),
                          child: Text('₹${_r(amt)}', style: ts(11.5, w: w8, c: Colors.white)),
                        )
                      : Text(lb, style: ts(11.5, w: a ? w8 : w7, c: col)),
                ]),
              ]),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: P.card,
            border: Border(top: BorderSide(color: P.bd)),
            boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, -4))],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 62,
              child: Row(children: [
                item('home', Icons.home_outlined, Icons.home_rounded, 'முகப்பு'),
                item('shops', Icons.storefront_outlined, Icons.storefront, 'கடைகள்'),
                item('orders', Icons.receipt_long_outlined, Icons.receipt_long, 'ஆர்டர்கள்', badge: Orders.I.badge),
                item('cart', Icons.shopping_cart_outlined, Icons.shopping_cart, 'கூடை', badge: n, cartLb: true),
              ]),
            ),
          ),
        );
      },
    );
  }

  static String _r(double v) {
    final s = v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
    return s.isEmpty ? '0' : s;
  }
}

// ═══ இணைய இணைப்பு பட்டை + "மீண்டும் முயற்சி" ═══
class NetBanner extends StatefulWidget {
  const NetBanner({super.key});
  @override
  State<NetBanner> createState() => _NetBannerState();
}

class _NetBannerState extends State<NetBanner> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _off = false, _back = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    try {
      Connectivity().checkConnectivity().then(_on);
      _sub = Connectivity().onConnectivityChanged.listen(_on);
    } catch (_) {}
  }

  void _on(List<ConnectivityResult> r) {
    final off = r.isEmpty || r.every((x) => x == ConnectivityResult.none);
    if (!mounted) return;
    if (_off && !off) {
      _t?.cancel();
      setState(() => _back = true);
      _t = Timer(const Duration(milliseconds: 2800), () {
        if (mounted) setState(() => _back = false);
      });
      if (AppState.I.cloudFail && !AppState.I.cloudLoading) AppState.I.runCloudLoad();
    }
    setState(() => _off = off);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (_off) return _bar('📴 இணைய இணைப்பு இல்லை', const Color(0xFFB91C1C));
    if (_back) return _bar('✅ இணைய இணைப்பு மீண்டும் கிடைத்தது', const Color(0xFF15803D));
    if (s.cloudFail && !s.cloudLoading) {
      return Material(
        color: const Color(0xFFFFF7E6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          child: Row(children: [
            Expanded(child: Text('⚠️ தகவல்களை ஏற்ற முடியவில்லை. தயவுசெய்து மீண்டும் முயற்சி செய்யுங்கள்.', style: ts(12.5, w: w7, c: const Color(0xFF9A5B00)))),
            TextButton(onPressed: () => s.runCloudLoad(), child: Text('மீண்டும் முயற்சி', style: ts(12.5, w: w8, c: const Color(0xFF9A5B00)))),
          ]),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _bar(String t, Color c) => Material(
        color: c,
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Text(t, textAlign: TextAlign.center, style: ts(13, w: w8, c: Colors.white))),
      );
}
