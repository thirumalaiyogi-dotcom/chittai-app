// சிட்டை — phone-ல் சேமிப்பு (web app-ன் localStorage key பெயர்களே)
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Store {
  static SharedPreferences? _p;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  static String? str(String k) {
    try {
      return _p?.getString(k);
    } catch (_) {
      return null;
    }
  }

  static void setStr(String k, String v) {
    try {
      _p?.setString(k, v);
    } catch (_) {}
  }

  static void remove(String k) {
    try {
      _p?.remove(k);
    } catch (_) {}
  }

  static dynamic json(String k) {
    final s = str(k);
    if (s == null) return null;
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  static void setJson(String k, Object? v) => setStr(k, jsonEncode(v));

  static double number(String k) => double.tryParse(str(k) ?? '') ?? 0;
}

// key பெயர்கள் (index.html-ல் உள்ளபடியே)
class K {
  static const profile = 'kd_profile';
  static const cart = 'citta_cart';
  static const ords = 'kd_ords';
  static const ordHidden = 'kd_ord_hidden';
  static const favs = 'sitta_favs';
  static const activeShop = 'kd_active_shop';
  static const shopChosen = 'kd_shop_chosen';
  static const userLoc = 'kd_user_loc';
  static const srchHist = 'kd_srch_hist';
  static const prods = 'kd_p';
  static const cats = 'kd_cats';
  static const shops = 'kd_shops';
  static const kinds = 'kd_kinds';
  static const banners = 'kd_banners';
  static const stories = 'kd_stories';
  static const popups = 'kd_popups';
  static const rev = 'kd_rev';
  static const wa = 'kd_wa';
  static const notice = 'kd_notice';
  static const storySeen = 'kd_story_seen';
  static const popupSeen = 'kd_popup_seen';
  static const revDone = 'kd_rev_done';
  static const ntSeen = 'kd_nt_seen';
  static const ntClr = 'kd_nt_clr';
  static const ntOff = 'kd_nt_off';
  static const theme = 'kd_theme';
  static const fs = 'kd_fs';
  static const mapSat = 'kd_map_sat';
  static const fabSeen = 'kd_fab_seen';
  static const cpush = 'sitta_cpush';
  static const firstRun = 'sa_customer_seen';
}
