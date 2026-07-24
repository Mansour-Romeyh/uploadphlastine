import 'package:online_ezzy/core/localization/get_x_import.dart';
import 'package:online_ezzy/core/services/api_service.dart';
import 'package:online_ezzy/core/utils/logger.dart';

class SettingsProvider extends GetxController {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Map<String, dynamic>? _settings;
  Map<String, dynamic>? get settings => _settings;

  String _currency = 'USD';
  String get currencyCode => _currency;

  String _currencySymbol = '\$';
  String get currencySymbol => _currencySymbol;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    update();
    try {
      final data = await ApiService.getSettings();
      if (data != null) {
        _settings = data;
        _currency = data['currency']?.toString().toUpperCase() ?? 'USD';
        _currencySymbol = data['currency_symbol']?.toString() ??
            _fallbackSymbol(_currency);
      }
    } catch (e) {
      logError('Error loading settings: $e');
    }
    _isLoading = false;
    update();
  }

  static String _fallbackSymbol(String code) {
    const symbols = {'USD': '\$', 'EUR': '€', 'GBP': '£'};
    return symbols[code.toUpperCase()] ?? code;
  }

  String formatPrice(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  String formatCurrency(double value) => '${formatPrice(value)} $_currencySymbol';

  String formatCurrencyWithLabel(String label, double value) =>
      '$label: ${formatCurrency(value)}';

  static double parsePrice(dynamic value) {
    final parsed = double.tryParse(
      value?.toString().trim().replaceAll(',', '.') ?? '',
    );
    if (parsed == null || parsed.isNaN || parsed.isInfinite || parsed < 0) {
      return 0;
    }
    return parsed;
  }
}
