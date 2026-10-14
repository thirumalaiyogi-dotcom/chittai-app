// Crispy — வாடிக்கையாளர் app (Flutter). தொடக்கம், splash, கீழ் பட்டை, tab-கள்.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'nav.dart';
import 'screens/cart.dart';
import 'orders.dart';
import 'push.dart';
import 'scooter.dart';
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
  // fonts app-க்குள்ளேயே (assets/google_fonts) — முதல் முறை offline-ஆக இருந்தாலும் எழுத்து சரியாக வரும்
  GoogleFonts.config.allowRuntimeFetching = false;
  // portrait மட்டும்
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Store.init();
  AppState.I.loadLocal();
  Popups.firstRun; // முதல் திறப்பா என்று படித்த பிறகு குறி
  Popups.markRun();
  runApp(ChangeNotifierProvider<AppState>.value(value: AppState.I, child: const ChittaiApp()));
  // HTML: pack_stock / inv — சேமித்த தரவிலும் உடனே, பிறகு +3s, +8s (ஒவ்வொரு cloud load-க்குப் பிறகும் runCloudLoad-ல்)
  unawaited(AppState.I.applyPackStock());
  Future.delayed(const Duration(seconds: 3), AppState.I.applyPackStock);
  Future.delayed(const Duration(seconds: 8), AppState.I.applyPackStock);
  unawaited(AppState.I.runCloudLoad());
  WidgetsBinding.instance.addObserver(_Resume());
}

// HTML visibilitychange: app மீண்டும் திறந்ததும் அறிவிப்பு / support எண் புதுப்பி
class _Resume extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.resumed) AppState.I.loadAppSettings();
  }
}

class ChittaiApp extends StatelessWidget {
  const ChittaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.select<AppState, bool>((s) => s.dark);
    final scale = context.select<AppState, double>((s) => s.textScale);
    return MaterialApp(
      title: 'Crispy',
      debugShowCheckedModeBanner: false,
      navigatorKey: Nav.root,
      theme: buildTheme(dark),
      builder: (c, child) => MediaQuery(
        // phone-ன் சொந்த எழுத்து அளவை (0.85–1.3 வரை) app-ன் அளவால் பெருக்கு — மாற்றி எழுதாதே
        data: MediaQuery.of(c).copyWith(
            textScaler: TextScaler.linear(
                (MediaQuery.textScalerOf(c).scale(100) / 100).clamp(0.85, 1.3).toDouble() * scale)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Boot(),
    );
  }
}

// ═══ Splash: scooter ஓடி வருகிறது → "Crispy." → app ═══
class Boot extends StatefulWidget {
  const Boot({super.key});
  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> with TickerProviderStateMixin {
  // அசைவு குறைப்பு: scooter splash-ஐ முழுவதும் தவிர்
  bool _done = reducedMotion, _out = reducedMotion;
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
            return AnnotatedRegion<SystemUiOverlayStyle>(
              // வெள்ளை splash-ல் light theme: status bar icons கருப்பு
              value: SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: dark ? Brightness.light : Brightness.dark, statusBarBrightness: dark ? Brightness.dark : Brightness.light),
              child: Opacity(
              opacity: (1 - (off - .4).clamp(0.0, 1.0) / .6).clamp(0.0, 1.0).toDouble(),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -.2),
                    radius: 1.2,
                    colors: dark ? const [Color(0xFF111B21), Color(0xFF111B21)] : const [Colors.white, AppColors.tint, Color(0xFFDCEFE1)],
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
                                color: dark ? AppColors.tint : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(color: Color(0x2E166534), blurRadius: 40, offset: Offset(0, 18)),
                                  BoxShadow(color: Color(0x8CFFFFFF), spreadRadius: 10),
                                ],
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(-w * 1.2 * (1 - ride) + w * 1.3 * off, -bob),
                            // web SVG (ஓட்டுநருடன் ஸ்கூட்டர்) — வலது பக்கம் பார்க்கும்; சக்கரம் சுழலும்
                            child: SittaScooter(spin: (_loop.value * 3) % 1),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 18),
                      Opacity(
                        opacity: name,
                        child: Transform.translate(
                          offset: Offset(0, 16 * (1 - name)),
                          child: RichText(
                            text: TextSpan(style: pop(40, c: dark ? const Color(0xFFE9EDEF) : AppColors.brand), children: const [
                              TextSpan(text: 'Crispy'),
                              TextSpan(text: '.', style: TextStyle(color: AppColors.primary)),
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
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          ),
                      ]),
                    ),
                  ),
                ]),
              ),
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
        decoration: BoxDecoration(shape: BoxShape.circle, color: (dark ? const Color(0xFF0B3D34) : const Color(0xFFC8E6CF)).withValues(alpha: .55)),
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
            const Positioned(left: 0, right: 0, top: 0, child: NetBanner()), // HTML .conn-bnr / .net-bnr: மேலே
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
        final dk = s.dark;
        // HTML .bn-it (light: 2222-2226; dark: 1474-1480)
        Widget item(String k, String svg, String lb, {int badge = 0, bool cartLb = false}) {
          final a = on == k;
          final lbCol = dk ? (a ? P.g2 : const Color(0xFF8A9592)) : (a ? AppColors.primaryDark : const Color(0xFF4D5752));
          final icCol = dk ? lbCol : (a ? AppColors.primary : const Color(0xFF6B7570));
          return Expanded(
            child: Semantics(
              button: true,
              selected: a,
              label: lb,
              excludeSemantics: true,
              child: InkWell(
              onTap: () => Nav.go(k),
              child: Stack(alignment: Alignment.center, children: [
                if (a)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: FractionallySizedBox(
                      widthFactor: .48, // left/right 26%
                      child: Container(height: 3.5, decoration: BoxDecoration(color: dk ? P.g : AppColors.primary, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)))),
                    ),
                  ),
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Stack(clipBehavior: Clip.none, children: [
                    LineIcon(svg, size: 25, stroke: a ? 2.4 : 2, color: icCol, fillAlpha: a ? .2 : 0),
                    if (badge > 0)
                      Positioned(
                        right: -9,
                        top: -5,
                        child: Container(
                          height: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          constraints: const BoxConstraints(minWidth: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: const Color(0xFFFF3B30), borderRadius: BorderRadius.circular(8)),
                          child: Text(badge > 99 ? '99+' : '$badge', textAlign: TextAlign.center, style: ts(12, w: w8, c: Colors.white, h: 1)),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 3),
                  cartLb && n > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(color: P.g, borderRadius: BorderRadius.circular(10)),
                          child: Text('₹${_r(amt)}', style: ts(12, w: w8, c: Colors.white)),
                        )
                      : Text(lb, style: ts(13, w: a ? w9 : w8, c: lbCol)),
                ]),
              ]),
            ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: dk ? P.card : Colors.white,
            border: Border(top: BorderSide(color: dk ? P.bd : const Color(0xFFE4E9E5))),
            boxShadow: [BoxShadow(color: dk ? const Color(0x0F000000) : const Color(0x0A143C32), blurRadius: dk ? 16 : 10, offset: Offset(0, dk ? -4 : -2))],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64, // HTML --bn: 64px (Home v3, வரி 1413)
              child: Row(children: [
                item('home', kIcHome, 'முகப்பு'),
                item('shops', kIcShops, 'கடைகள்'),
                item('orders', kIcOrders, 'ஆர்டர்கள்', badge: Orders.I.badge),
                item('cart', kIcCart, 'கூடை', badge: n, cartLb: true),
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
    final top = MediaQuery.of(context).padding.top;
    if (_off) return _bar('📴 இணைய இணைப்பு இல்லை', const Color(0xFFC0392B), top);
    if (_back) return _bar('✅ இணைய இணைப்பு மீண்டும் கிடைத்தது', const Color(0xFF16A34A), top);
    if (s.cloudFail && !s.cloudLoading) {
      // HTML .net-bnr
      return Material(
        color: const Color(0xFFFFF4E5),
        child: Container(
          padding: EdgeInsets.fromLTRB(12, 8 + top, 12, 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0C987)))),
          child: Row(children: [
            Expanded(child: Text('⚠️ தகவல்களை ஏற்ற முடியவில்லை. தயவுசெய்து மீண்டும் முயற்சி செய்யுங்கள்.', style: ts(12, w: w7, c: const Color(0xFF8A5300)))),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => s.runCloudLoad(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: P.or, borderRadius: BorderRadius.circular(8)),
                child: Text('மீண்டும் முயற்சி', style: ts(12, w: w8, c: Colors.white)),
              ),
            ),
          ]),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // HTML .conn-bnr
  Widget _bar(String t, Color c, double top) => Material(
        color: c,
        child: Padding(padding: EdgeInsets.fromLTRB(12, 8 + top, 12, 8), child: Text(t, textAlign: TextAlign.center, style: ts(13, w: w8, c: Colors.white))),
      );
}
