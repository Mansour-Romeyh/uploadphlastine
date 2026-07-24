import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:online_ezzy/core/localization/app_translations.dart';
import 'package:online_ezzy/core/localization/get_x_import.dart';
import 'package:online_ezzy/core/services/api_service.dart';
import 'package:online_ezzy/core/services/payment_service.dart';
import 'package:online_ezzy/core/utils/logger.dart';
import 'package:online_ezzy/core/widgets/cached_image.dart';
import 'package:online_ezzy/core/widgets/empty_state.dart';
import 'package:online_ezzy/features/auth/controllers/auth_provider.dart';
import 'package:online_ezzy/features/cart/controllers/cart_provider.dart';
import 'package:online_ezzy/features/settings/controllers/settings_provider.dart';

import 'paypal_approval_page.dart';

enum _CheckoutMethod { stripe, paypal }

class CartPage extends StatefulWidget {
  const CartPage({Key? key}) : super(key: key);

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool _isProcessingPayment = false;
  _CheckoutMethod _selectedCheckoutMethod = _CheckoutMethod.stripe;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cartProvider = Get.find<CartProvider>();
      cartProvider.refreshCart();
      cartProvider.refreshAvailablePaymentMethods();
    });
  }

  bool _isOrderCreated(Map<String, dynamic>? result) {
    if (result == null) return false;
    if (result['code'] != null || result['error'] != null) return false;
    final statusCode = result['status_code'] as int? ?? 0;
    if (statusCode >= 400) return false;
    final status = result['status']?.toString().toLowerCase() ?? '';
    if (status == 'failed' || status == 'cancelled' || status == 'canceled') {
      return false;
    }
    final hasOrderId = result['id'] != null || result['order_id'] != null;
    return hasOrderId ||
        status == 'processing' ||
        status == 'completed' ||
        status == 'pending' ||
        status == 'on-hold';
  }

  bool _isPaymentCompleted(Map<String, dynamic>? result) {
    if (!_isOrderCreated(result)) return false;
    final status = result?['status']?.toString().toLowerCase() ?? '';
    if (status == 'processing' || status == 'completed') return true;
    final paymentResult = result?['payment_result'];
    if (paymentResult is Map) {
      final paymentStatus =
          paymentResult['payment_status']?.toString().toLowerCase() ?? '';
      if (paymentStatus == 'success' || paymentStatus == 'succeeded') {
        return true;
      }
      if (paymentStatus == 'failure' || paymentStatus == 'failed') return false;
    }
    return false;
  }

  String _extractOrderError(Map<String, dynamic>? result) {
    if (result == null) return 'فشل إنشاء الطلب، حاول مرة أخرى'.tr;
    final message = result['message']?.toString();
    final data = result['data'];
    final nestedMessage = data is Map ? data['message']?.toString() : null;
    final code = result['code']?.toString();
    final combined = [
      message,
      nestedMessage,
      code,
    ].whereType<String>().join(' ').toLowerCase();
    if (combined.contains('account is already registered') ||
        combined.contains('email') && combined.contains('registered') ||
        combined.contains('registration-error-email-exists') ||
        combined.contains('تم تسجيل حساب بالفعل') ||
        combined.contains('يحمل') && combined.contains('البريد')) {
      return 'هذا البريد مسجل بالفعل. سجل الدخول أولاً بنفس الحساب ثم أعد الطلب.'
          .tr;
    }
    final paymentResult = result['payment_result'];
    if (paymentResult is Map) {
      final paymentDetails = paymentResult['payment_details'];
      if (paymentDetails is List) {
        for (final entry in paymentDetails) {
          if (entry is Map &&
              entry['key']?.toString() == 'errorMessage' &&
              (entry['value']?.toString().isNotEmpty ?? false)) {
            return entry['value'].toString();
          }
        }
      }
    }
    if (message != null && message.isNotEmpty) return message;
    if (nestedMessage != null && nestedMessage.isNotEmpty) return nestedMessage;
    if (code != null && code.isNotEmpty) return code;
    final statusCode = result['status_code']?.toString();
    if (statusCode != null && statusCode.isNotEmpty) {
      return 'فشل إنشاء الطلب (كود: $statusCode)'.tr;
    }
    return 'فشل إنشاء الطلب، حاول مرة أخرى'.tr;
  }

  Map<String, dynamic> _buildBillingAddress() {
    final userData = Get.find<AuthProvider>().userData ?? {};
    final billing = userData['billing'] is Map
        ? Map<String, dynamic>.from(userData['billing'])
        : <String, dynamic>{};
    final shipping = userData['shipping'] is Map
        ? Map<String, dynamic>.from(userData['shipping'])
        : <String, dynamic>{};

    String pick(List<dynamic> values, String fallback) {
      for (final value in values) {
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    final guestEmail =
        'guest_${DateTime.now().millisecondsSinceEpoch}@onlineezzy.app';
    return {
      'first_name': pick([
        billing['first_name'],
        shipping['first_name'],
        userData['first_name'],
        userData['name'],
      ], 'Online'),
      'last_name': pick([
        billing['last_name'],
        shipping['last_name'],
        userData['last_name'],
      ], 'Ezzy'),
      'email': pick([billing['email'], userData['email']], guestEmail),
      'phone': pick([billing['phone'], userData['phone']], '0100000000'),
      'address_1': pick([
        billing['address_1'],
        shipping['address_1'],
      ], 'OnlineEzzy'),
      'city': pick([billing['city'], shipping['city']], 'Hebron'),
      'state': pick([billing['state'], shipping['state']], 'Hebron'),
      'postcode': pick([billing['postcode'], shipping['postcode']], '00000'),
      'country': pick([
        billing['country'],
        shipping['country'],
        userData['country'],
      ], 'PS'),
    };
  }

  Map<String, dynamic> _buildGuestBillingAddress() {
    final billing = Map<String, dynamic>.from(_buildBillingAddress());
    billing['email'] =
        'guest_${DateTime.now().millisecondsSinceEpoch}@onlineezzy.app';
    return billing;
  }

  int _extractItemQuantity(Map<String, dynamic> item) {
    final quantityRaw = item['quantity'];
    if (quantityRaw is Map) {
      return int.tryParse((quantityRaw['value'] ?? '1').toString()) ?? 1;
    }
    return int.tryParse(quantityRaw?.toString() ?? '1') ?? 1;
  }

  double _safeParseMajor(dynamic value) {
    final raw = value?.toString().trim().replaceAll(',', '.') ?? '';
    final parsed = double.tryParse(raw);
    if (parsed == null || parsed.isNaN || parsed.isInfinite || parsed < 0) {
      return 0;
    }
    return parsed;
  }

  double _extractUnitPrice(Map<String, dynamic> item) {
    final prices = item['prices'];
    if (prices is Map) {
      final minor = int.tryParse(prices['price']?.toString() ?? '');
      if (minor != null && minor >= 0) return minor / 100;
    }
    return _safeParseMajor(item['price']);
  }

  double _extractLineTotal(Map<String, dynamic> item, int quantity) {
    final totals = item['totals'];
    if (totals is Map) {
      final lineMinor = int.tryParse(totals['line_total']?.toString() ?? '');
      final lineTaxMinor =
          int.tryParse(totals['line_total_tax']?.toString() ?? '0') ?? 0;
      if (lineMinor != null && lineMinor >= 0) {
        return (lineMinor + lineTaxMinor) / 100;
      }
    }
    return _extractUnitPrice(item) * quantity;
  }

  double _calculateCartTotalMajor(List<dynamic> items) {
    double total = 0;
    for (final raw in items) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      total += _extractLineTotal(item, _extractItemQuantity(item));
    }
    return total;
  }

  String _formatPrice(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  String _formatCurrency(double value, SettingsProvider settings) =>
      '${_formatPrice(value)} ${settings.currencySymbol}';

  String _cleanErrorMessage(dynamic error) {
    final raw = error?.toString().trim() ?? '';
    if (raw.isEmpty) return 'فشل إتمام الطلب';
    var text = raw;
    while (text.startsWith('Exception: ')) {
      text = text.substring('Exception: '.length).trim();
    }
    return text.isEmpty ? 'فشل إتمام الطلب' : text;
  }

  Future<void> _storeSuccessfulOrder({
    required String orderId,
    required String status,
    required String paymentMethodTitle,
    required double totalMajor,
    required String currencyCode,
  }) async {
    final raw = GetStorage().read<String>('local_success_orders');
    final existing = <Map<String, dynamic>>[];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) existing.add(Map<String, dynamic>.from(item));
          }
        }
      } catch (_) {}
    }
    existing.removeWhere((o) => o['id']?.toString() == orderId);
    existing.insert(0, {
      'id': orderId,
      'status': status,
      'date_created': DateTime.now().toIso8601String(),
      'total': totalMajor.toStringAsFixed(2),
      'currency': currencyCode.toUpperCase(),
      'payment_method_title': paymentMethodTitle,
      'line_items': const [
        {'name': 'طلب جديد', 'quantity': 1},
      ],
      'is_local_cached': true,
    });
    if (existing.length > 30) existing.removeRange(30, existing.length);
    await GetStorage().write('local_success_orders', jsonEncode(existing));
  }

  Future<Map<String, dynamic>?> _checkoutNativeStripe(
    CartProvider cartProvider,
    Map<String, dynamic> billingAddress,
    double amount,
    String currency,
  ) async {
    try {
      final cartToken = cartProvider.cartToken;
      if (cartToken == null || cartToken.isEmpty) {
        throw Exception('Cart token is missing');
      }
      return await PaymentService.processNativeStripePayment(
        amount: amount,
        currency: currency,
        cartToken: cartToken,
        billingAddress: billingAddress,
        merchantDisplayName: 'OnlineEzzy',
      );
    } catch (e) {
      return {'success': false, 'error': true, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _checkoutPaypalFlow({
    required CartProvider cartProvider,
    required Map<String, dynamic> billingAddress,
  }) async {
    final cartToken = cartProvider.cartToken;
    if (cartToken == null || cartToken.isEmpty) {
      throw Exception('Cart token is missing');
    }
    final create = await ApiService.createPaypalOrder(cartToken: cartToken);
    final createStatus = create['status_code'] as int? ?? 500;
    if (createStatus >= 400) {
      throw Exception(
        create['message']?.toString().isNotEmpty == true
            ? create['message'].toString()
            : 'فشل إنشاء طلب PayPal',
      );
    }
    final approvalUrl =
        create['approval_url']?.toString() ??
        create['approve_url']?.toString() ??
        '';
    final createdOrderId = create['paypal_order_id']?.toString() ?? '';
    if (approvalUrl.isEmpty || createdOrderId.isEmpty) {
      throw Exception('رد إنشاء طلب PayPal غير مكتمل');
    }
    final returnedToken = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PayPalApprovalPage(approvalUrl: approvalUrl),
      ),
    );
    final paypalOrderId = (returnedToken?.trim().isNotEmpty ?? false)
        ? returnedToken!.trim()
        : createdOrderId;
    return ApiService.capturePaypalOrder(
      paypalOrderId: paypalOrderId,
      cartToken: cartToken,
      billingAddress: billingAddress,
    );
  }

  void _removeItem(String itemKey) =>
      Get.find<CartProvider>().removeCartItem(itemKey);

  // ─── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            'السلة'.tr,
            style: const TextStyle(
              color: Color(0xFF1E3A5F),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: GetBuilder<CartProvider>(
          builder: (cartProvider) {
            return GetBuilder<SettingsProvider>(
              builder: (settingsProvider) {
                if (cartProvider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.red),
                  );
                }

                final cartItems = cartProvider.cartItems;
                final cartTotal = _calculateCartTotalMajor(cartItems);
                final knownMethods = cartProvider.availablePaymentMethods;
                final hasKnownMethods = knownMethods.isNotEmpty;
                final hasStripe =
                    !hasKnownMethods || knownMethods.contains('stripe');
                final hasPaypal =
                    knownMethods.contains('paypal') ||
                    knownMethods.any((m) => m.contains('ppcp'));

                if (cartItems.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.shopping_cart_outlined,
                    title: 'السلة فارغة',
                    subtitle: 'لم تقم بإضافة أي منتجات بعد',
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      // ── قائمة المنتجات ──
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cartItems.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _buildCartItem(cartItems[i], settingsProvider),
                      ),

                      const SizedBox(height: 16),

                      // ── طرق الدفع + الإجمالي ──
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'طريقة الدفع',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildPaymentOption(
                              title: 'الدفع بالبطاقة',
                              subtitle: 'Stripe — آمن وسريع',
                              iconData: Icons.credit_card_rounded,
                              iconColor: const Color(0xFF0EA5E9),
                              selected:
                                  _selectedCheckoutMethod ==
                                  _CheckoutMethod.stripe,
                              enabled: hasStripe,
                              onTap: () => setState(
                                () => _selectedCheckoutMethod =
                                    _CheckoutMethod.stripe,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildPaymentOption(
                              title: 'الدفع عبر PayPal',
                              subtitle: 'بوابة PayPal الرسمية',
                              iconData: Icons.paypal_rounded,
                              iconColor: const Color(0xFF2563EB),
                              selected:
                                  _selectedCheckoutMethod ==
                                  _CheckoutMethod.paypal,
                              enabled: hasPaypal,
                              onTap: () => setState(
                                () => _selectedCheckoutMethod =
                                    _CheckoutMethod.paypal,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(
                                height: 1,
                                color: Color(0xFFEEF0F3),
                              ),
                            ),
                            // الإجمالي
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'الإجمالي',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  _formatCurrency(cartTotal, settingsProvider),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A5F),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ── تفريغ السلة ──
                      TextButton.icon(
                        onPressed: () => Get.find<CartProvider>().clearCart(),
                        icon: const Icon(
                          Icons.delete_sweep_outlined,
                          color: Color(0xFFCBD5E1),
                          size: 16,
                        ),
                        label: Text(
                          'تفريغ السلة'.tr,
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 12,
                          ),
                        ),
                      ),

                      const SizedBox(height: 90),
                    ],
                  ),
                );
              },
            );
          },
        ),
        bottomSheet: GetBuilder<CartProvider>(
          builder: (cartProvider) {
            return GetBuilder<SettingsProvider>(
              builder: (settingsProvider) {
                final cartTotal = _calculateCartTotalMajor(
                  cartProvider.cartItems,
                );
                final isPaypalFlow =
                    _selectedCheckoutMethod == _CheckoutMethod.paypal;

                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFEEF0F3))),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          cartProvider.cartItems.isEmpty || _isProcessingPayment
                          ? null
                          : () async {
                              setState(() => _isProcessingPayment = true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('جاري المعالجة...'.tr)),
                              );
                              try {
                                final billingAddress =
                                    _selectedCheckoutMethod ==
                                        _CheckoutMethod.stripe
                                    ? (Get.find<AuthProvider>().isAuthenticated
                                          ? _buildBillingAddress()
                                          : _buildGuestBillingAddress())
                                    : _buildBillingAddress();

                                Map<String, dynamic>? result;
                                final availableMethods = await cartProvider
                                    .refreshAvailablePaymentMethods();

                                if (_selectedCheckoutMethod ==
                                    _CheckoutMethod.stripe) {
                                  if (!availableMethods.contains('stripe')) {
                                    throw Exception(
                                      'Stripe غير متاح حالياً من إعدادات المتجر'
                                          .tr,
                                    );
                                  }
                                  result = await _checkoutNativeStripe(
                                    cartProvider,
                                    billingAddress,
                                    cartTotal,
                                    settingsProvider.currencyCode,
                                  );
                                } else if (_selectedCheckoutMethod ==
                                    _CheckoutMethod.paypal) {
                                  final paypalMethod = availableMethods
                                      .firstWhere(
                                        (m) =>
                                            m == 'paypal' || m.contains('ppcp'),
                                        orElse: () => '',
                                      );
                                  if (paypalMethod.isEmpty) {
                                    throw Exception(
                                      'PayPal غير متاح حالياً من إعدادات المتجر'
                                          .tr,
                                    );
                                  }
                                  result = await _checkoutPaypalFlow(
                                    cartProvider: cartProvider,
                                    billingAddress: billingAddress,
                                  );
                                }

                                if (!context.mounted) return;
                                ScaffoldMessenger.of(
                                  context,
                                ).hideCurrentSnackBar();

                                if (_selectedCheckoutMethod ==
                                    _CheckoutMethod.stripe) {
                                  final stripeOrderCreated = _isOrderCreated(
                                    result,
                                  );
                                  final stripePaymentCompleted =
                                      _isPaymentCompleted(result);
                                  if (result?['success'] == true &&
                                      stripeOrderCreated &&
                                      stripePaymentCompleted) {
                                    final orderId = result?['order_id']
                                        ?.toString();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          (orderId != null
                                                  ? 'تم الدفع بنجاح! رقم الطلب: $orderId'
                                                  : 'تم الدفع بنجاح!')
                                              .tr,
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    if (orderId != null && orderId.isNotEmpty) {
                                      await _storeSuccessfulOrder(
                                        orderId: orderId,
                                        status:
                                            result?['status']?.toString() ??
                                            'processing',
                                        paymentMethodTitle: 'Stripe',
                                        totalMajor: cartTotal,
                                        currencyCode:
                                            settingsProvider.currencyCode,
                                      );
                                    }
                                    await cartProvider.clearCart();
                                    await cartProvider.refreshCart();
                                  } else if (stripeOrderCreated &&
                                      !stripePaymentCompleted) {
                                    final orderId = result?['order_id']
                                        ?.toString();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          (orderId != null
                                                  ? 'الدفع لم يكتمل للطلب رقم: $orderId'
                                                  : 'الدفع لم يكتمل، حاول مرة أخرى')
                                              .tr,
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  } else if (result?['cancelled'] == true) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'تم إلغاء عملية الدفع'.tr,
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          (result?['message']?.toString() ??
                                                  'فشل الدفع، حاول مرة أخرى')
                                              .tr,
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } else {
                                  final orderCreated = _isOrderCreated(result);
                                  if (orderCreated) {
                                    final orderId =
                                        result?['order_id']?.toString() ??
                                        result?['id']?.toString();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          (orderId != null
                                                  ? 'تم إنشاء الطلب بنجاح! رقم الطلب: $orderId'
                                                  : 'تم إنشاء الطلب بنجاح!')
                                              .tr,
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    if (orderId != null && orderId.isNotEmpty) {
                                      await _storeSuccessfulOrder(
                                        orderId: orderId,
                                        status:
                                            result?['status']?.toString() ??
                                            'pending',
                                        paymentMethodTitle:
                                            result?['payment_method_title']
                                                ?.toString() ??
                                            'PayPal',
                                        totalMajor: cartTotal,
                                        currencyCode:
                                            settingsProvider.currencyCode,
                                      );
                                    }
                                    await cartProvider.clearCart();
                                    await cartProvider.refreshCart();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          _extractOrderError(result),
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(
                                  context,
                                ).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'فشل إتمام الطلب: ${_cleanErrorMessage(e)}',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isProcessingPayment = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE71D24),
                        disabledBackgroundColor: const Color(
                          0xFFE71D24,
                        ).withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isProcessingPayment
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              isPaypalFlow ? 'تأكيد الطلب'.tr : 'ادفع الآن'.tr,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCartItem(dynamic item, SettingsProvider settings) {
    final itemMap = item is Map
        ? Map<String, dynamic>.from(item)
        : <String, dynamic>{};
    logInfo('🛍️ Cart item data: $itemMap');

    final id = itemMap['key']?.toString() ?? itemMap['id']?.toString() ?? '';
    final title = itemMap['name']?.toString() ?? 'منتج';
    // final subtitle = itemMap['description']?.toString() ?? '';
    final quantity = _extractItemQuantity(itemMap);
    final unitPrice = _extractUnitPrice(itemMap);
    final lineTotal = _extractLineTotal(itemMap, quantity);

    var imageUrl = '';
    if (itemMap['images'] != null && (itemMap['images'] as List).isNotEmpty) {
      imageUrl = itemMap['images'][0]['src'] ?? '';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // صورة المنتج
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedImage(
              imageUrl: imageUrl,
              width: 68,
              height: 68,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          // تفاصيل المنتج
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$quantity × ${_formatCurrency(unitPrice, settings)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      _formatCurrency(lineTotal, settings),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // زر الحذف
          GestureDetector(
            onTap: () => _removeItem(id),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required IconData iconData,
    required Color iconColor,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFE71D24).withValues(alpha: 0.05)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFFE71D24)
                  : const Color(0xFFE2E8F0),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(iconData, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected
                    ? const Color(0xFFE71D24)
                    : const Color(0xFFCBD5E1),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
