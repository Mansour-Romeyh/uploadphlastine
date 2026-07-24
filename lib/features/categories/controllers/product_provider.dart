import 'package:online_ezzy/core/localization/get_x_import.dart';
import 'package:online_ezzy/core/services/api_service.dart';
import 'package:online_ezzy/core/utils/logger.dart';

class ProductProvider extends GetxController {
  bool _isLoading = false;
  bool _isCategoriesLoading = false;

  bool get isLoading => _isLoading;
  bool get isCategoriesLoading => _isCategoriesLoading;

  List<dynamic> _products = [];
  List<dynamic> get products => _products;

  List<dynamic> _deliveryProducts = [];
  List<dynamic> get deliveryProducts => _deliveryProducts;

  List<dynamic> _categories = [];
  List<dynamic> get categories => _categories;

  ProductProvider() {
    loadCategories();
    loadProducts();
  }

  Future<void> loadCategories() async {
    _isCategoriesLoading = true;
    update();

    try {
      _categories = await ApiService.getCategories().timeout(
        const Duration(seconds: 8),
        onTimeout: () => <dynamic>[],
      );
    } catch (e) {
      logError('Load categories error: $e');
    } finally {
      _isCategoriesLoading = false;
      update();
    }
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    update();

    try {
      _products = await ApiService.getProducts().timeout(
        const Duration(seconds: 8),
        onTimeout: () => <dynamic>[],
      );
    } catch (e) {
      logError('Load products error: $e');
    } finally {
      _isLoading = false;
      update();
    }
  }

  Future<void> loadProductsByCategory(int categoryId) async {
    _isLoading = true;
    update();

    try {
      _deliveryProducts = await ApiService.getProducts(
        categoryId: categoryId,
      ).timeout(const Duration(seconds: 8), onTimeout: () => <dynamic>[]);
    } catch (e) {
      logError('Load category products error: $e');
    } finally {
      _isLoading = false;
      update();
    }
  }

  Future<void> loadProductsByCategories(List<int> categoryIds) async {
    _isLoading = true;
    update();

    try {
      _deliveryProducts = await ApiService.getProducts(
        categoryIds: categoryIds,
      ).timeout(const Duration(seconds: 8), onTimeout: () => <dynamic>[]);
    } catch (e) {
      logError('Load categories products error: $e');
    } finally {
      _isLoading = false;
      update();
    }
  }

  Future<void> loadDeliveryProducts({
    int categoryId = 68,
    List<int>? categoryIds,
  }) async {
    if (categoryIds != null && categoryIds.isNotEmpty) {
      await loadProductsByCategories(categoryIds);
      return;
    }
    await loadProductsByCategory(categoryId);
  }
}
