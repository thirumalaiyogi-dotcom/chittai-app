// Crispy — 📱 Firebase push: ஆர்டர் நிலை மாறியதும் app மூடியிருந்தாலும் notification
// server பகுதி: backend/push_fcm.sql (save_order_fcm) + backend/notify.ts (v10)
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'api.dart';
import 'config.dart';
import 'orders.dart';
import 'state.dart';
import 'store.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets.dart';
import 'screens/orders.dart';

class Push {
  static bool get configured => kFbApiKey.isNotEmpty && kFbAppId.isNotEmpty && kFbSenderId.isNotEmpty && kFbProjectId.isNotEmpty;
  static bool _inited = false;
  static final ValueNotifier<int> changed = ValueNotifier(0);

  static Future<bool> init() async {
    if (!configured) return false;
    if (_inited) return true;
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(apiKey: kFbApiKey, appId: kFbAppId, messagingSenderId: kFbSenderId, projectId: kFbProjectId),
      );
      _inited = true;
      // app திறந்திருக்கும்போது வந்தால்: சிறிய செய்தி + ஆர்டர் நிலை புதுப்பி
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) toast('🔔 ${n.title ?? ''}${(n.body ?? '').isNotEmpty ? '\n${n.body}' : ''}');
        Orders.I.fetch(force: true);
      });
      FirebaseMessaging.onMessageOpenedApp.listen(_open);
      final first = await FirebaseMessaging.instance.getInitialMessage();
      if (first != null) Future.delayed(const Duration(seconds: 3), () => _open(first));
      return true;
    } catch (_) {
      return false;
    }
  }

  static void _open(RemoteMessage m) {
    final id = js(m.data['order_id']);
    if (kUuid.hasMatch(id)) openTrack(id);
  }

  static List<String> done() {
    final a = Store.json(K.cpush);
    return a is List ? a.map((x) => js(x)).toList() : <String>[];
  }

  static void _mark(String id) {
    final a = done();
    if (!a.contains(id)) {
      a.insert(0, id);
      Store.setJson(K.cpush, a.take(50).toList());
    }
    changed.value++;
  }

  static Future<bool> granted() async {
    if (!await init()) return false;
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return s.authorizationStatus == AuthorizationStatus.authorized;
    } catch (_) {
      return false;
    }
  }

  // இந்த ஆர்டரை இந்த phone-உடன் இணை (ஆர்டர் id + அதே mobile எண்)
  static Future<bool> enable(String oid, String ph, {bool silent = false}) async {
    if (!await init()) {
      if (!silent) toast('⚠️ Notification வசதி இன்னும் அமைக்கப்படவில்லை');
      return false;
    }
    try {
      final fm = FirebaseMessaging.instance;
      if (silent) {
        if (!await granted()) return false;
      } else {
        final s = await fm.requestPermission();
        if (s.authorizationStatus != AuthorizationStatus.authorized) {
          toast('⚠️ Notification அனுமதி மறுக்கப்பட்டது — Phone Settings → Apps → Crispy → Notifications → Allow');
          return false;
        }
      }
      final tok = await fm.getToken();
      if (tok == null || tok.isEmpty) throw Exception('token');
      final r = await Api.rpc('save_order_fcm', {'p_order_id': oid, 'p_phone': ph, 'p_token': tok});
      final d = r.data is Map ? r.data as Map : null;
      if (d == null || d['ok'] != true) throw Exception(d != null && js(d['msg']).isNotEmpty ? js(d['msg']) : (r.status == 404 ? 'server அமைப்பு இன்னும் இல்லை (push_fcm.sql)' : 'சேமிக்க முடியவில்லை'));
      _mark(oid);
      if (!silent) toast('🔔 இந்த order நிலை மாறியதும் notification வரும்');
      return true;
    } catch (e) {
      if (!silent) toast('⚠️ இயக்க முடியவில்லை — ${e.toString().replaceFirst('Exception: ', '')}');
      return false;
    }
  }

  // அனுமதி ஏற்கனவே இருந்தால்: கடந்த 3 நாள் ஆர்டர்களை அமைதியாக இணை
  static Future<void> linkRecent() async {
    if (!configured || !await granted()) return;
    final d = done();
    final now = DateTime.now().millisecondsSinceEpoch;
    final l = AppState.I.ordLocal().where((o) => kUuid.hasMatch(js(o['oid'])) && js(o['ph']).isNotEmpty && now - jz(o['ts']) < 3 * 864e5 && !d.contains(js(o['oid']))).take(5);
    for (final o in l) {
      await enable(js(o['oid']), js(o['ph']), silent: true);
    }
  }
}

// "🔔 Order நிலை மாறியதும் notification பெற" பொத்தான் / இயக்கப்பட்ட செய்தி
class PushBlock extends StatelessWidget {
  final String oid, ph;
  final EdgeInsets margin;
  const PushBlock({super.key, required this.oid, required this.ph, this.margin = const EdgeInsets.fromLTRB(14, 12, 14, 0)});

  @override
  Widget build(BuildContext context) {
    if (!Push.configured || !kUuid.hasMatch(oid)) return const SizedBox.shrink();
    return ValueListenableBuilder<int>(
      valueListenable: Push.changed,
      builder: (_, __, ___) {
        if (Push.done().contains(oid)) {
          return Container(
            margin: margin,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: P.gc, borderRadius: BorderRadius.circular(10)),
            child: Text('🔔 நிலை மாறியதும் இந்த phone-க்கு notification வரும்', textAlign: TextAlign.center, style: ts(12.5, w: w7, c: P.g2)),
          );
        }
        return Padding(
          padding: margin,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(12),
              backgroundColor: P.card,
              side: BorderSide(color: P.g, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Push.enable(oid, ph),
            child: Text('🔔 Order நிலை மாறியதும் notification பெற', style: ts(14, w: w8, c: P.g2)),
          ),
        );
      },
    );
  }
}
