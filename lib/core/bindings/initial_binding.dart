import 'package:online_ezzy/core/localization/get_x_import.dart';
import 'package:online_ezzy/features/auth/controllers/auth_provider.dart';
import 'package:online_ezzy/features/cart/controllers/cart_provider.dart';
import 'package:online_ezzy/features/categories/controllers/product_provider.dart';
import 'package:online_ezzy/features/dashboard/controllers/dashboard_provider.dart';
import 'package:online_ezzy/features/settings/controllers/settings_provider.dart';
import 'package:online_ezzy/features/shipments/controllers/shipment_provider.dart';

void registerRootDependencies() {
  Get.put(SettingsProvider(), permanent: true);
  Get.put(AuthProvider(), permanent: true);
  Get.put(CartProvider(), permanent: true);
  Get.put(ProductProvider(), permanent: true);
  Get.put(ShipmentProvider(), permanent: true);
  Get.put(DashboardProvider(), permanent: true);
}
