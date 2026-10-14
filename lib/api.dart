// Crispy — Supabase அழைப்புகள். index.html-ல் உள்ள அதே URL, அதே headers (anon key மட்டும்).
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

class ApiResult {
  final int status; // 0 = network பிழை
  final dynamic data;
  final String body;
  const ApiResult(this.status, this.data, this.body);
  bool get ok => status >= 200 && status < 300;
}

class Api {
  static final http.Client _c = http.Client();

  static Map<String, String> get headers => const {
        'Content-Type': 'application/json',
        'apikey': kSbKey,
        'Authorization': 'Bearer $kSbKey',
      };

  static Future<ApiResult> _send(Future<http.Response> f) async {
    try {
      final r = await f.timeout(const Duration(seconds: 20));
      final body = utf8.decode(r.bodyBytes);
      dynamic data;
      try {
        data = body.isEmpty ? null : jsonDecode(body);
      } catch (_) {
        data = null;
      }
      return ApiResult(r.statusCode, data, body);
    } catch (_) {
      return const ApiResult(0, null, '');
    }
  }

  static Future<ApiResult> getPath(String pathAndQuery) =>
      _send(_c.get(Uri.parse('$kSbUrl/rest/v1/$pathAndQuery'), headers: headers));

  // sbGet: table?select=*  → List அல்லது null (பிழை)
  static Future<ApiResult> table(String t) => getPath('$t?select=*');

  static Future<ApiResult> rpc(String fn, Object body, {Duration timeout = const Duration(seconds: 20)}) async {
    try {
      final r = await _c
          .post(Uri.parse('$kSbUrl/rest/v1/rpc/$fn'), headers: headers, body: jsonEncode(body))
          .timeout(timeout);
      final s = utf8.decode(r.bodyBytes);
      dynamic data;
      try {
        data = s.isEmpty ? null : jsonDecode(s);
      } catch (_) {
        data = null;
      }
      return ApiResult(r.statusCode, data, s);
    } catch (_) {
      return const ApiResult(0, null, '');
    }
  }
}
