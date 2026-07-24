import 'package:get_storage/get_storage.dart';
import 'package:online_ezzy/core/localization/get_x_import.dart';
import 'package:online_ezzy/core/services/api_service.dart';
import 'package:online_ezzy/core/utils/logger.dart';

class CartProvider extends GetxController {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<dynamic> _cartItems = [];
  List<dynamic> get cartItems => _cartItems;

  List<String> _paymentMethods = [];
  List<String> get availablePaymentMethods => _paymentMethods;

  String? _lastCheckoutError;
  String? get lastCheckoutError => _lastCheckoutError;

  String? _cartToken;
  String? get cartToken => _cartToken;

  final Set<int> _addingProductIds = {};
  bool isAddingProduct(int id) => _addingProductIds.contains(id);

  CartProvider() {
    _loadCart();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> refreshCart() => _loadCart();

  Future<List<String>> refreshAvailablePaymentMethods() async {
    try {
      final cart = await ApiService.getCartWithMeta(cartToken: await _token());
      await _saveToken(cart['cart_token']?.toString());
      _extractPaymentMethods(cart['data']);
      update();
    } catch (e) {
      logError('refreshPaymentMethods: $e');
    }
    return _paymentMethods;
  }

  Future<bool> addToCart(
    int productId,
    int quantity, {
    int? variationId,
  }) async {
    _addingProductIds.add(productId);
    _isLoading = true;
    update();

    try {
      var effectiveVariation = variationId;
      var res = await ApiService.addCartItemWithMeta(
        productId: productId,
        quantity: quantity,
        variationId: effectiveVariation,
        cartToken: await _token(),
      );

      // Auto-resolve variation if backend requires one
      if (_isFailed(res) &&
          effectiveVariation == null &&
          _isVariationMismatch(res['data'])) {
        final vars = await ApiService.getProductVariations(productId);
        effectiveVariation = _firstPurchasableVariation(vars);
        if (effectiveVariation != null) {
          res = await ApiService.addCartItemWithMeta(
            productId: productId,
            quantity: quantity,
            variationId: effectiveVariation,
            cartToken: await _token(),
          );
        }
      }

      // Recover from stale session
      if (_isFailed(res)) {
        await _resetToken();
        final bootstrap = await ApiService.getCartWithMeta(cartToken: null);
        await _saveToken(bootstrap['cart_token']?.toString());
        res = await ApiService.addCartItemWithMeta(
          productId: productId,
          quantity: quantity,
          variationId: effectiveVariation,
          cartToken: _cartToken,
        );
        if (_isFailed(res)) return false;
      }

      await _saveToken(res['cart_token']?.toString());
      await _refreshItems();
      return true;
    } catch (e) {
      logError('addToCart: $e');
      return false;
    } finally {
      _addingProductIds.remove(productId);
      _isLoading = false;
      update();
    }
  }

  Future<bool> removeCartItem(String itemKey) async {
    final backup = List<dynamic>.from(_cartItems);
    _cartItems.removeWhere((i) => i['key']?.toString() == itemKey);
    _isLoading = true;
    update();

    try {
      final res = await ApiService.deleteCartItemWithMeta(
        itemKey: itemKey,
        cartToken: await _token(),
      );
      if (_isFailed(res)) {
        throw Exception('delete failed: ${res['status_code']}');
      }
      await _saveToken(res['cart_token']?.toString());
      await _refreshItems();
      return true;
    } catch (e) {
      logError('removeCartItem: $e');
      _cartItems = backup;
    } finally {
      _isLoading = false;
      update();
    }
    return false;
  }

  Future<bool> updateCartItemQuantity(String itemKey, int quantity) async {
    _isLoading = true;
    update();
    try {
      final res = await ApiService.editCartItemWithMeta(
        itemKey: itemKey,
        quantity: quantity,
        cartToken: await _token(),
      );
      await _saveToken(res['cart_token']?.toString());
      await _refreshItems();
      return true;
    } catch (e) {
      logError('updateCartItem: $e');
      return false;
    } finally {
      _isLoading = false;
      update();
    }
  }

  Future<void> clearCart() async {
    _isLoading = true;
    update();
    try {
      final res = await ApiService.clearCartWithMeta(cartToken: await _token());
      await _saveToken(res['cart_token']?.toString());
      _cartItems = [];
      update();
    } catch (e) {
      logError('clearCart: $e');
    } finally {
      _isLoading = false;
      update();
    }
  }

  Future<Map<String, dynamic>?> checkout(
    Map<String, dynamic> checkoutData, {
    bool useAuth = true,
  }) async {
    _isLoading = true;
    _lastCheckoutError = null;
    update();

    try {
      // Ensure fresh cart session before checkout
      await _bootstrapCart();
      if (_cartToken == null) {
        return _checkoutError(
          'missing_cart_token',
          'تعذر الوصول إلى جلسة السلة.',
          400,
        );
      }

      var res = await ApiService.checkout(
        _cartToken!,
        checkoutData,
        useAuth: useAuth,
      );

      // Retry on token/session issues
      if (!_isSuccess(res) && _shouldRetry(res)) {
        await _resetToken();
        await _bootstrapCart();
        if (_cartToken != null) {
          res = await ApiService.checkout(
            _cartToken!,
            checkoutData,
            useAuth: useAuth,
          );
        }
      }

      if (_isSuccess(res)) {
        _cartItems = [];
        return res;
      }

      _lastCheckoutError =
          res['message']?.toString() ?? res['code']?.toString();
      return res;
    } catch (e) {
      logError('checkout: $e');
      _lastCheckoutError = e.toString();
      return _checkoutError('checkout_exception', _lastCheckoutError!, 500);
    } finally {
      _isLoading = false;
      update();
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _loadCart() async {
    _isLoading = true;
    update();
    try {
      await _bootstrapCart();
      await _refreshItems();
    } catch (e) {
      logError('loadCart: $e');
      _cartItems = [];
    } finally {
      _isLoading = false;
      update();
    }
  }

  Future<void> _bootstrapCart() async {
    final bootstrap = await ApiService.getCartWithMeta(
      cartToken: await _token(),
    );
    await _saveToken(bootstrap['cart_token']?.toString());
    _extractPaymentMethods(bootstrap['data']);
  }

  Future<void> _refreshItems() async {
    final res = await ApiService.getCartItemsWithMeta(cartToken: _cartToken);
    await _saveToken(res['cart_token']?.toString());
    _cartItems = res['items'] as List? ?? [];
  }

  Future<String?> _token() async {
    if (_cartToken != null) return _cartToken;
    _cartToken = GetStorage().read<String>('cart_token');
    // Invalidate legacy tokens (old versions stored timestamps without dots)
    if (_cartToken != null && !_cartToken!.contains('.')) {
      await _resetToken();
    }
    return _cartToken;
  }

  Future<void> _saveToken(String? token) async {
    if (token == null || token.isEmpty) return;
    _cartToken = token;
    await GetStorage().write('cart_token', token);
  }

  Future<void> _resetToken() async {
    _cartToken = null;
    await GetStorage().remove('cart_token');
  }

  void _extractPaymentMethods(dynamic data) {
    if (data is! Map<String, dynamic>) return;
    final raw = data['payment_methods'];
    if (raw is List) {
      _paymentMethods = raw
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }
  }

  static bool _isFailed(Map<String, dynamic> res) {
    final code = res['status_code'] as int? ?? 500;
    return code < 200 || code >= 300;
  }

  static bool _isSuccess(Map<String, dynamic> res) {
    final status = res['status']?.toString().toLowerCase() ?? '';
    final code = res['status_code'] as int? ?? 0;
    return res['code'] == null &&
        res['error'] == null &&
        (code == 200 || code == 201) &&
        (res['id'] != null ||
            status == 'processing' ||
            status == 'completed' ||
            status == 'pending' ||
            status == 'on-hold');
  }

  static bool _shouldRetry(Map<String, dynamic> res) {
    final code = res['status_code'] as int? ?? 0;
    final err = '${res['code'] ?? ''} ${res['message'] ?? ''}'.toLowerCase();
    return code == 401 ||
        code == 403 ||
        err.contains('token') ||
        err.contains('cart');
  }

  static bool _isVariationMismatch(dynamic data) =>
      data is Map &&
      data['code']?.toString() ==
          'woocommerce_rest_variation_id_from_variation_data';

  static int? _firstPurchasableVariation(List<dynamic> variations) {
    for (final raw in variations) {
      if (raw is! Map) continue;
      final v = Map<String, dynamic>.from(raw);
      final id = int.tryParse(v['id']?.toString() ?? '');

      if (id == null || id <= 0) continue;
      final status = v['status']?.toString().toLowerCase() ?? '';
      if (status.isNotEmpty && status != 'publish') continue;
      if (v['purchasable'] == false) continue;
      return id;
    }
    return null;
  }

  static Map<String, dynamic> _checkoutError(
    String code,
    String message,
    int statusCode,
  ) => {'code': code, 'message': message, 'status_code': statusCode};
}
