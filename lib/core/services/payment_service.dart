import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:online_ezzy/core/utils/logger.dart';

import 'api_service.dart';

/// Service to handle native Stripe payments (Updated for existing backend)
class PaymentService {
  static bool _isPaymentSheetFlowRunning = false;
  static String _cleanMessage(dynamic error, {String fallback = 'حدث خطأ'}) {
    final raw = error?.toString().trim() ?? '';
    if (raw.isEmpty) return fallback;
    var text = raw;
    if (text.startsWith('Exception: ')) {
      text = text.substring('Exception: '.length).trim();
    }
    return text.isEmpty ? fallback : text;
  }

  /// Creates a payment intent directly via Stripe API
  static Future<Map<String, dynamic>> createPaymentIntent({
    required double amount,
    required String currency,
  }) async {
    try {
      final response = await ApiService.createStripePaymentIntent(
        amount: amount,
        currency: currency,
      );

      if (response['client_secret'] == null && response['error'] == null) {
        logError(
          '⚠️ Warning: createPaymentIntent response missing client_secret and error: $response',
        );

        throw Exception(response['message'] ?? 'فشل إنشاء نية الدفع');
      }

      if (response['error'] != null) {
        throw Exception(response['error'].toString());
      }

      return response;
    } catch (e) {
      throw Exception('خطأ في إنشاء نية الدفع: ${e.toString()}');
    }
  }

  /// Initializes Stripe Payment Sheet
  static Future<void> initializePaymentSheet({
    required String clientSecret,
    required String merchantDisplayName,
  }) async {
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: merchantDisplayName,
          style: ThemeMode.light,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(primary: Color(0xFFE71D24)),
          ),
        ),
      );
    } on StripeException catch (e) {
      throw Exception('فشل تهيئة صفحة الدفع: ${e.error.localizedMessage}');
    }
  }

  /// Presents the payment sheet to user
  static Future<void> presentPaymentSheet() async {
    try {
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      final errorCode = e.error.code;

      if (errorCode == FailureCode.Canceled) {
        throw PaymentCancelledException('تم إلغاء عملية الدفع');
      } else if (errorCode == FailureCode.Failed) {
        throw PaymentFailedException(e.error.localizedMessage ?? 'فشل الدفع');
      } else {
        throw Exception(e.error.localizedMessage ?? 'حدث خطأ أثناء الدفع');
      }
    }
  }

  /// Confirms order after successful payment using WooCommerce checkout
  static Future<Map<String, dynamic>> confirmOrder({
    required String paymentIntentId,
    String? paymentIntentClientSecret,
    String? stripePaymentMethodId,
    required Map<String, dynamic> billingAddress,
    required String cartToken,
  }) async {
    try {
      final response = await ApiService.checkoutWithStripePayment(
        paymentIntentId: paymentIntentId,
        paymentIntentClientSecret: paymentIntentClientSecret,
        stripePaymentMethodId: stripePaymentMethodId,
        billingAddress: billingAddress,
        cartToken: cartToken,
      );

      if (response['order_id'] == null && response['id'] == null) {
        throw Exception(response['message'] ?? 'فشل تأكيد الطلب');
      }

      final status = response['status']?.toString().toLowerCase() ?? '';
      if (status == 'failed' || status == 'cancelled' || status == 'canceled') {
        String? paymentError;
        final paymentResult = response['payment_result'];
        if (paymentResult is Map) {
          final paymentDetails = paymentResult['payment_details'];
          if (paymentDetails is List) {
            for (final entry in paymentDetails) {
              if (entry is Map &&
                  entry['key']?.toString() == 'errorMessage' &&
                  (entry['value']?.toString().isNotEmpty ?? false)) {
                paymentError = entry['value'].toString();
                break;
              }
            }
          }
        }
        throw Exception(
          paymentError ??
              (response['message']?.toString().isNotEmpty == true
                  ? response['message'].toString()
                  : 'تم إنشاء الطلب لكن حالة الدفع فشلت'),
        );
      }

      return response;
    } catch (e) {
      throw Exception('خطأ في تأكيد الطلب: ${_cleanMessage(e)}');
    }
  }

  /// Complete native Stripe payment flow (Updated for existing backend)
  static Future<Map<String, dynamic>> processNativeStripePayment({
    required double amount,
    required String currency,
    required String cartToken,
    required Map<String, dynamic> billingAddress,
    String merchantDisplayName = 'OnlineEzzy',
  }) async {
    if (_isPaymentSheetFlowRunning) {
      return {
        'success': false,
        'busy': true,
        'message': 'عملية دفع أخرى قيد التنفيذ، يرجى الانتظار قليلاً',
      };
    }

    _isPaymentSheetFlowRunning = true;
    String? paymentIntentId;
    try {
      // Step 1: Create Payment Intent via Stripe API
      final paymentIntentData = await createPaymentIntent(
        amount: amount,
        currency: currency,
      );

      final clientSecret = paymentIntentData['client_secret']?.toString();
      paymentIntentId =
          paymentIntentData['payment_intent_id']?.toString() ??
          paymentIntentData['id']?.toString();
      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('لم يتم استلام client_secret من الخادم');
      }
      if (paymentIntentId == null || paymentIntentId.isEmpty) {
        throw Exception('لم يتم استلام payment_intent_id من الخادم');
      }

      // Step 2: Initialize Payment Sheet
      await initializePaymentSheet(
        clientSecret: clientSecret,
        merchantDisplayName: merchantDisplayName,
      );

      // Stripe iOS SDK can be unstable when present follows immediately.
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Step 3: Present Payment Sheet
      await presentPaymentSheet();

      String? stripePaymentMethodId;
      try {
        final retrieved = await Stripe.instance.retrievePaymentIntent(
          clientSecret,
        );
        stripePaymentMethodId = retrieved.paymentMethodId;
      } catch (_) {}

      // #endregion

      // Step 4: Confirm Order via WooCommerce checkout
      final orderData = await confirmOrder(
        paymentIntentId: paymentIntentId,
        paymentIntentClientSecret: clientSecret,
        stripePaymentMethodId: stripePaymentMethodId,
        billingAddress: billingAddress,
        cartToken: cartToken,
      );

      return {
        'success': true,
        'order_id': orderData['order_id'] ?? orderData['id'],
        'status': orderData['status'] ?? 'processing',
        'payment_intent_id': paymentIntentId,
        ...orderData,
      };
    } on PaymentCancelledException catch (e) {
      return {'success': false, 'cancelled': true, 'message': e.message};
    } on PaymentFailedException catch (e) {
      return {'success': false, 'failed': true, 'message': e.message};
    } catch (e) {
      return {
        'success': false,
        'error': true,
        'message': _cleanMessage(e, fallback: 'حدث خطأ أثناء الدفع'),
        'payment_intent_id': paymentIntentId,
      };
    } finally {
      _isPaymentSheetFlowRunning = false;
    }
  }
}

/// Custom exception for cancelled payments
class PaymentCancelledException implements Exception {
  final String message;
  PaymentCancelledException(this.message);
}

/// Custom exception for failed payments
class PaymentFailedException implements Exception {
  final String message;
  PaymentFailedException(this.message);
}
