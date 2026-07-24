import 'dart:async';
import 'dart:convert';

import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:online_ezzy/core/utils/logger.dart';

class ApiService {
  static const String _base = 'https://onlineezzy.com/wp-json';

  static Future<void> Function()? onUnauthorized;
  static bool _handlingUnauthorized = false;

  static const _timeout = Duration(seconds: 15);

  // ── Helpers ───────────────────────────────────────────────────────────────

  static dynamic _decode(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'raw_body': body};
    }
  }

  static Map<String, String> _headers({String? bearer, String? cartToken}) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (bearer != null) 'Authorization': 'Bearer $bearer',
    if (cartToken != null) 'Cart-Token': cartToken,
  };

  static String? get _bearerToken => GetStorage().read<String>('auth_token');

  static Map<String, String> _authHeaders({String? cartToken}) =>
      _headers(bearer: _bearerToken, cartToken: cartToken);

  static bool _isUnauth(int status) => status == 401 || status == 403;

  static Map<String, dynamic> _withStatus(dynamic decoded, int status) {
    final map = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};
    return {...map, 'status_code': status};
  }

  static Map<String, dynamic> _cartMeta(http.Response res, dynamic decoded) => {
    'data': decoded,
    'status_code': res.statusCode,
    'cart_token': res.headers['cart-token'] ?? res.headers['Cart-Token'],
  };

  static Map<String, dynamic> _cartTokenHeader(http.Response res) => {
    'cart_token': res.headers['cart-token'] ?? res.headers['Cart-Token'],
  };

  static Future<void> _handleUnauthorized(
    Map<String, String> headers,
    int status,
  ) async {
    if (!_isUnauth(status)) return;
    if (!(headers['Authorization'] ?? '').startsWith('Bearer ')) return;
    if (onUnauthorized == null || _handlingUnauthorized) return;
    _handlingUnauthorized = true;
    try {
      await onUnauthorized!();
    } finally {
      _handlingUnauthorized = false;
    }
  }

  static Future<Map<String, dynamic>> _postAuthed(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final headers = _headers(bearer: _bearerToken);
    final res = await http
        .post(Uri.parse(endpoint), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    await _handleUnauthorized(headers, res.statusCode);
    return _withStatus(_decode(res.body), res.statusCode);
  }

  /// GET مع Bearer token
  static Future<http.Response> _authedGet(String path) async {
    final url = Uri.parse('$_base/$path');
    return http.get(url, headers: _authHeaders());
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final res = await http
        .post(
          Uri.parse('$_base/jwt-auth/v1/token'),
          body: {'username': username, 'password': password},
        )
        .timeout(_timeout);
    return _withStatus(jsonDecode(res.body), res.statusCode);
  }

  static Future<Map<String, dynamic>> getCustomerDetails() async {
    final res = await http
        .get(Uri.parse('$_base/ezzy/v1/profile'), headers: _authHeaders())
        .timeout(_timeout);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateCustomerDetails(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/ezzy/v1/update_profile'),
            headers: {
              'Authorization': 'Bearer $_bearerToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(data),
          )
          .timeout(_timeout);
      if (res.statusCode == 200) return jsonDecode(res.body);
      return {'error': 'Failed to update customer'};
    } catch (_) {
      return {'error': 'Timeout or network error'};
    }
  }

  // ── Products & Categories ─────────────────────────────────────────────────

  static Future<List<dynamic>> getCategories() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_base/ezzy/v1/catalog/categories'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d is List) return d;
      }
      logError('getCategories: ${res.statusCode}');
    } catch (e) {
      logError('getCategories: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getProducts({
    int? categoryId,
    List<int>? categoryIds,
  }) async {
    try {
      final params = <String, String>{};
      if (categoryIds != null && categoryIds.isNotEmpty) {
        params['category_id'] = categoryIds.join(',');
      } else if (categoryId != null) {
        params['category_id'] = '$categoryId';
      }
      final url = Uri.parse(
        '$_base/ezzy/v1/catalog/products',
      ).replace(queryParameters: params.isEmpty ? null : params);
      final res = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d is List) return d;
      }
      logError('getProducts: ${res.statusCode}');
    } catch (e) {
      logError('getProducts: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getProductVariations(
    int productId, {
    int perPage = 100,
  }) async {
    try {
      final url = Uri.parse(
        '$_base/ezzy/v1/catalog/products/$productId/variations',
      ).replace(queryParameters: {'per_page': '$perPage'});
      final res = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d is List) return d;
      }
      logError('getProductVariations($productId): ${res.statusCode}');
    } catch (e) {
      logError('getProductVariations($productId): $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>> getSingleCategory(String id) async {
    final res = await http.get(
      Uri.parse('$_base/ezzy/v1/catalog/categories/$id'),
      headers: {'Accept': 'application/json'},
    );
    return jsonDecode(res.body);
  }

  // ── Cart ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getCartWithMeta({
    String? cartToken,
  }) async {
    final res = await http.get(
      Uri.parse('$_base/wc/store/v1/cart'),
      headers: _authHeaders(cartToken: cartToken),
    );
    final decoded = _decode(res.body);
    final items = decoded is Map ? (decoded['items'] as List?) ?? [] : [];
    return {'items': items, 'data': decoded, ..._cartTokenHeader(res)};
  }

  static Future<Map<String, dynamic>> getCartItemsWithMeta({
    String? cartToken,
  }) async {
    final res = await http.get(
      Uri.parse('$_base/wc/store/v1/cart/items'),
      headers: _authHeaders(cartToken: cartToken),
    );
    final decoded = _decode(res.body);
    final items = decoded is List
        ? decoded
        : (decoded is Map ? (decoded['items'] as List?) ?? [] : []);
    return {'items': items, ..._cartTokenHeader(res)};
  }

  static Future<Map<String, dynamic>> addCartItemWithMeta({
    required int productId,
    required int quantity,
    int? variationId,
    String? cartToken,
  }) async {
    final itemId = (variationId != null && variationId > 0)
        ? variationId
        : productId;
    logInfo('🛒 addToCart id=$itemId qty=$quantity');
    final res = await http.post(
      Uri.parse('$_base/wc/store/v1/cart/items'),
      headers: _authHeaders(cartToken: cartToken),
      body: jsonEncode({'id': itemId, 'quantity': quantity}),
    );
    logInfo('🛒 status=${res.statusCode}');
    return _cartMeta(res, _decode(res.body));
  }

  static Future<Map<String, dynamic>> editCartItemWithMeta({
    required String itemKey,
    required int quantity,
    String? cartToken,
  }) async {
    final headers = _authHeaders(cartToken: cartToken);
    final res = await http.put(
      Uri.parse('$_base/wc/store/v1/cart/items/$itemKey?quantity=$quantity'),
      headers: headers,
    );
    await _handleUnauthorized(headers, res.statusCode);
    return _cartMeta(res, _decode(res.body));
  }

  static Future<Map<String, dynamic>> deleteCartItemWithMeta({
    required String itemKey,
    String? cartToken,
  }) async {
    final headers = _authHeaders(cartToken: cartToken);
    final res = await http.delete(
      Uri.parse('$_base/wc/store/v1/cart/items/$itemKey'),
      headers: headers,
    );
    await _handleUnauthorized(headers, res.statusCode);
    return _cartMeta(res, _decode(res.body));
  }

  static Future<Map<String, dynamic>> clearCartWithMeta({
    String? cartToken,
  }) async {
    final headers = _authHeaders(cartToken: cartToken);
    final res = await http.delete(
      Uri.parse('$_base/wc/store/v1/cart/items'),
      headers: headers,
    );
    await _handleUnauthorized(headers, res.statusCode);
    return _cartMeta(res, _decode(res.body));
  }

  // ── Orders ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getOrder(String orderId) async {
    final res = await http.get(
      Uri.parse('$_base/wc/v3/orders/$orderId'),
      headers: _authHeaders(),
    );
    if (res.statusCode != 200) return null;
    final d = _decode(res.body);
    return d is Map<String, dynamic> ? d : null;
  }

  static Future<List<Map<String, dynamic>>> getCustomerOrders(
    String customerId, {
    int perPage = 50,
  }) async {
    final res = await http.get(
      Uri.parse(
        '$_base/wc/v3/orders?customer=$customerId&per_page=$perPage&orderby=date&order=desc',
      ),
      headers: _authHeaders(),
    );
    if (res.statusCode != 200) return [];
    final d = _decode(res.body);
    if (d is! List) return [];
    return d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // ── Checkout ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> checkout(
    String cartToken,
    Map<String, dynamic> checkoutData, {
    bool useAuth = true,
  }) async {
    final headers = _headers(
      bearer: useAuth ? _bearerToken : null,
      cartToken: cartToken,
    );
    final res = await http.post(
      Uri.parse('$_base/wc/store/v1/checkout'),
      headers: headers,
      body: jsonEncode(checkoutData),
    );
    await _handleUnauthorized(headers, res.statusCode);
    return _withStatus(_decode(res.body), res.statusCode);
  }

  // ── PayPal ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createPaypalOrder({
    required String cartToken,
  }) => _postAuthed('$_base/ezzy/v1/paypal/create-order', {
    'cart_token': cartToken,
  });

  static Future<Map<String, dynamic>> capturePaypalOrder({
    required String paypalOrderId,
    required String cartToken,
    required Map<String, dynamic> billingAddress,
  }) => _postAuthed('$_base/ezzy/v1/paypal/capture-order', {
    'paypal_order_id': paypalOrderId,
    'cart_token': cartToken,
    'billing_address': billingAddress,
  });

  // ── Stripe ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createStripePaymentIntent({
    required double amount,
    required String currency,
  }) async {
    try {
      return await _postAuthed('$_base/ezzy/v1/stripe/create-payment-intent', {
        'amount': double.parse(amount.toStringAsFixed(2)),
        'currency': currency.toLowerCase(),
      });
    } on TimeoutException {
      return {
        'error': 'timeout',
        'message': 'تعذر الاتصال بخدمة الدفع. تحقق من الاتصال وحاول مرة أخرى.',
        'status_code': 504,
      };
    } catch (e) {
      return {'error': e.toString(), 'status_code': 500};
    }
  }

  static Future<Map<String, dynamic>> checkoutWithStripePayment({
    required String paymentIntentId,
    String? paymentIntentClientSecret,
    String? stripePaymentMethodId,
    required Map<String, dynamic> billingAddress,
    required String cartToken,
  }) async {
    try {
      return await _postAuthed('$_base/ezzy/v1/stripe/complete-order', {
        'payment_intent_id': paymentIntentId,
        'cart_token': cartToken,
        'billing_address': billingAddress,
      });
    } on TimeoutException {
      return {
        'error': 'timeout',
        'message': 'الطلب استغرق وقتاً أطول من المتوقع. حاول مرة أخرى.',
        'status_code': 504,
      };
    } catch (e) {
      return {'error': e.toString(), 'status_code': 500};
    }
  }

  // ── Ezzy endpoints ────────────────────────────────────────────────────────

  static Future<dynamic> getShipments() async {
    final res = await _authedGet('ezzy/v1/shipments');
    if (res.statusCode == 200) {
      final d = _decode(res.body);
      if (d is List) return d;
      if (d is Map<String, dynamic>) return d['data'] ?? d['shipments'] ?? d;
    }
    if (_isUnauth(res.statusCode)) return _decode(res.body);
    return [];
  }

  static Future<dynamic> getShipmentDetails(String id) async {
    final res = await _authedGet('ezzy/v1/shipments/$id');
    if (res.statusCode == 200) {
      final d = _decode(res.body);
      if (d is Map<String, dynamic>) return d;
      if (d is List && d.isNotEmpty && d.first is Map) {
        return Map<String, dynamic>.from(d.first as Map);
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getDashboard() async {
    final res = await http.get(
      Uri.parse('$_base/ezzy/v1/dashboard'),
      headers: _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  static Future<List<dynamic>> getSliders() async {
    var res = await http.get(
      Uri.parse('$_base/ezzy/v1/sliders'),
      headers: {'Accept': 'application/json'},
    );
    if (_isUnauth(res.statusCode)) {
      res = await http.get(Uri.parse('$_base/ezzy/v1/sliders'));
    }
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<Map<String, dynamic>?> trackShipment(String number) async {
    final res = await getShipmentDetails(number);
    return res is Map<String, dynamic> ? res : null;
  }

  static Future<List<dynamic>> getNotifications() async {
    final res = await _authedGet('ezzy/v1/notifications');
    if (res.statusCode == 200) {
      final d = _decode(res.body);
      if (d is List) return d;
      if (d is Map<String, dynamic>) {
        return (d['data'] ?? d['notifications'] ?? []) as List;
      }
      return [];
    }
    final d = _decode(res.body);
    final msg = d is Map
        ? d['message']?.toString() ??
              d['code']?.toString() ??
              'تعذر تحميل الإشعارات'
        : 'تعذر تحميل الإشعارات';
    throw Exception('notifications_${res.statusCode}: $msg');
  }

  static Future<int> getUnreadNotificationsCount() async {
    try {
      final items = await getNotifications();
      return items.where((raw) {
        if (raw is! Map) return false;
        final m = Map<String, dynamic>.from(raw);
        return m['isUnread'] == true ||
            m['is_unread'] == true ||
            m['read'] == false;
      }).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> markNotificationAsRead(String id) async {
    final res = await _authedGet('ezzy/v1/notifications/$id/read');
    return res.statusCode == 200 || res.statusCode == 201;
  }

  static Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final res = await http.post(
      Uri.parse('$_base/ezzy/v1/change_password'),
      headers: {
        'Authorization': 'Bearer $_bearerToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>?> getSettings() async {
    final res = await http.get(
      Uri.parse('$_base/ezzy/v1/settings'),
      headers: _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  static Future<Map<String, dynamic>?> contactUs(
    Map<String, dynamic> data,
  ) async {
    final res = await http.post(
      Uri.parse('$_base/ezzy/v1/contact'),
      headers: {
        'Authorization': 'Bearer $_bearerToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body);
    }
    return null;
  }
}
