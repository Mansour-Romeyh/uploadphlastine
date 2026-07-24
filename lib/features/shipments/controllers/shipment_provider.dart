import 'dart:async';

import 'package:online_ezzy/core/localization/get_x_import.dart';
import 'package:online_ezzy/core/services/api_service.dart';
import 'package:online_ezzy/core/utils/image_url_utils.dart';
import 'package:online_ezzy/core/utils/logger.dart';

class ShipmentProvider extends GetxController {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _shipments = [];
  List<Map<String, dynamic>> get shipments => _shipments;

  String? _error;
  String? get error => _error;

  bool _requiresAuth = false;
  bool get requiresAuth => _requiresAuth;

  ShipmentProvider() {
    loadShipments();
  }

  Future<void> loadShipments() async {
    _isLoading = true;
    _error = null;
    _requiresAuth = false;
    update();
    try {
      final res = await ApiService.getShipments()
          .timeout(const Duration(seconds: 10), onTimeout: () => <dynamic>[]);

      if (res is List) {
        _shipments = res
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (res is Map && res['code'] == 'rest_forbidden') {
        _requiresAuth = true;
        _error = 'يجب تسجيل الدخول لعرض الشحنات';
      }
    } catch (e) {
      _error = 'حدث خطأ في تحميل الشحنات';
      logError('Error loading shipments: $e');
    } finally {
      _isLoading = false;
      update();
    }
  }

  Future<Map<String, dynamic>?> getShipmentDetails(String id) async {
    try {
      return await ApiService.getShipmentDetails(id);
    } on TimeoutException {
      return null;
    } catch (e) {
      logError('Error loading shipment details: $e');
      return null;
    }
  }

  String getShipmentImageUrl(Map<dynamic, dynamic>? shipment) =>
      shipmentImageUrl(shipment);

  Future<Map<String, dynamic>?> trackShipment(String trackingNumber) async {
    _isLoading = true;
    update();
    try {
      return await ApiService.trackShipment(trackingNumber);
    } catch (e) {
      logError('Error tracking shipment: $e');
      return null;
    } finally {
      _isLoading = false;
      update();
    }
  }
}
