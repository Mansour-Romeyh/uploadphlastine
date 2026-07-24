import 'dart:convert';

import 'package:get_storage/get_storage.dart';
import 'package:online_ezzy/core/localization/get_x_import.dart';
import 'package:online_ezzy/core/services/api_service.dart';
import 'package:online_ezzy/core/utils/logger.dart';

class AuthProvider extends GetxController {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _token;
  String? get token => _token;
  bool get isAuthenticated => _token?.isNotEmpty == true;

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? get userData => _userData;

  String? _lastError;
  String? get lastError => _lastError;

  AuthProvider() {
    _loadSession();
  }

  Future<void> _loadSession() async {
    final box = GetStorage();
    _token = box.read<String>('auth_token');
    final userStr = box.read<String>('user_data');
    if (userStr != null) {
      try {
        final d = jsonDecode(userStr);
        _userData = d is Map<String, dynamic>
            ? d
            : (d as Map).map((k, v) => MapEntry(k.toString(), v));
      } catch (e) {
        logError('Auth: parse user data: $e');
      }
    }
    final id = _userData?['user_id']?.toString();
    if (isAuthenticated && id != null) await fetchCustomerDetails(id);
    update();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<bool> login(String username, String password) async {
    return _withLoading(() async {
      final res = await ApiService.login(username, password);
      if (res['token'] != null) {
        await _saveSession(res['token'] as String, res);
        return true;
      }
      _lastError =
          res['message']?.toString() ??
          res['code']?.toString() ??
          'فشل تسجيل الدخول';
      return false;
    });
  }

  Future<bool> fetchCustomerDetails(String id) async {
    try {
      final res = await ApiService.getCustomerDetails();
      if (res.containsKey('user_id')) {
        _userData = {...?_userData, ...res};
        await GetStorage().write('user_data', jsonEncode(_userData));
        update();
        return true;
      }
    } catch (e) {
      logError('fetchCustomerDetails: $e');
    }
    return false;
  }

  Future<bool> updateCustomerDetails(
    String id,
    Map<String, dynamic> data,
  ) async {
    return _withLoading(() async {
      final res = await ApiService.updateCustomerDetails(id, data);
      if (res.containsKey('error')) {
        _lastError = res['error']?.toString();
        return false;
      }
      _userData = {...?_userData, ...res};
      await GetStorage().write('user_data', jsonEncode(_userData));
      return true;
    });
  }

  Future<void> logout() async {
    final box = GetStorage();
    await box.remove('auth_token');
    await box.remove('user_data');
    _token = null;
    _userData = null;
    update();
  }

  // ── Computed display values ───────────────────────────────────────────────

  String get displayName {
    // بعد fetchCustomerDetails تكون first_name/last_name متاحة من WooCommerce
    final first = _userData?['first_name']?.toString().trim() ?? '';
    final last = _userData?['last_name']?.toString().trim() ?? '';
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;

    // fallback على name من JWT
    final name = _userData?['user_display_name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;

    final localPart = primaryEmail.split('@').first.trim();
    if (localPart.isNotEmpty && !localPart.contains('@')) return localPart;

    return isAuthenticated ? 'مستخدم' : 'ضيف';
  }

  String get primaryEmail {
    final email = _userData?['user_email']?.toString().trim() ?? '';
    return email.isNotEmpty ? email : '';
  }

  // ── Static utilities ──────────────────────────────────────────────────────

  static dynamic valueByPath(Map<String, dynamic>? source, String path) {
    dynamic cur = source;
    for (final part in path.split('.')) {
      if (cur is Map && cur.containsKey(part)) {
        cur = cur[part];
      } else {
        return null;
      }
    }
    return cur;
  }

  static String? extractUserId(Map<String, dynamic>? source) {
    final id = source?['user_id']?.toString().trim() ?? '';
    return (id.isEmpty || id.toLowerCase() == 'null') ? null : id;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<bool> _withLoading(Future<bool> Function() fn) async {
    _isLoading = true;
    _lastError = null;
    update();
    try {
      return await fn();
    } catch (e) {
      _lastError = 'خطأ في الاتصال بالشبكة';
      logError('AuthProvider: $e');
      return false;
    } finally {
      _isLoading = false;
      update();
    }
  }

  Future<void> _saveSession(String token, Map<String, dynamic> data) async {
    _token = token;
    _userData = data;
    final box = GetStorage();
    await box.write('auth_token', token);
    await box.write('user_data', jsonEncode(data));
    final id = data['user_id']?.toString();
    if (id != null) await fetchCustomerDetails(id);
  }
}
