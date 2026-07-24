import 'dart:async';

import 'package:flutter/material.dart';
import 'package:online_ezzy/core/localization/app_translations.dart';
import 'package:online_ezzy/core/localization/get_x_import.dart';
import 'package:online_ezzy/core/services/api_service.dart';
import 'package:online_ezzy/core/utils/logger.dart';
import 'package:online_ezzy/core/widgets/cached_image.dart';
import 'package:online_ezzy/core/widgets/product_card.dart';
import 'package:online_ezzy/features/auth/controllers/auth_provider.dart';
import 'package:online_ezzy/features/categories/controllers/product_provider.dart';
import 'package:online_ezzy/features/categories/pages/addresses_page.dart';
import 'package:online_ezzy/features/dashboard/controllers/dashboard_provider.dart';
import 'package:online_ezzy/features/settings/pages/settings_page.dart';
import 'package:online_ezzy/features/shipments/controllers/shipment_provider.dart';
import 'package:online_ezzy/features/shipments/pages/shipments_page.dart';
import 'package:online_ezzy/features/shipments/pages/track_page.dart';

import 'package:online_ezzy/features/products/pages/product_detail_page.dart';

import 'notifications_page.dart';
import 'category_products_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;
  int _bannerIndex = 0;
  late Future<int> _unreadNotificationsFuture;

  @override
  void initState() {
    super.initState();
    _unreadNotificationsFuture = ApiService.getUnreadNotificationsCount()
        .timeout(const Duration(seconds: 6), onTimeout: () => 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBannerTimer();
    });
  }

  void _refreshUnreadNotificationsCount() {
    setState(() {
      _unreadNotificationsFuture = ApiService.getUnreadNotificationsCount()
          .timeout(const Duration(seconds: 6), onTimeout: () => 0);
    });
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_bannerController.hasClients) return;
      final dp = Get.find<DashboardProvider>();
      final len = dp.sliders.isNotEmpty ? dp.sliders.length : 3;
      final next = (_bannerIndex + 1) % len;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            const SizedBox(height: 8),
            _TopHeader(
              notificationsFuture: _unreadNotificationsFuture,
              onTapDashboard: () => _openPage(const SettingsPage()),
              onTapNotification: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationsPage(),
                  ),
                );
                _refreshUnreadNotificationsCount();
              },
            ),
            const SizedBox(height: 28),
            _TopActionsRow(
              onTapDelivery: () => _openPage(
                const CategoryProductsPage(
                  categoryId: 68,
                  pageTitle: 'طلب توصيل',
                ),
              ),
              onTapTrack: () => _openPage(const ShipmentsPage()),
              onTapAddress: () => _openPage(const AddressesPage()),
              onTapServices: () => _openPage(
                const CategoryProductsPage(
                  categoryId: 66,
                  pageTitle: 'خدمات مالية',
                ),
              ),
            ),
            const SizedBox(height: 28),
            GetBuilder<DashboardProvider>(
              builder: (dashboard) {
                if (dashboard.isLoading && dashboard.sliders.isEmpty) {
                  return Container(
                    height: 180,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE71D24),
                      ),
                    ),
                  );
                }

                List<String> images = dashboard.sliders
                    .whereType<String>()
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();

                if (images.isEmpty) {
                  logError(
                    'لا توجد صور بانر صالحة من الباك إند، يتم استخدام الصور الافتراضية.',
                  );
                }

                return _HeroSlider(
                  controller: _bannerController,
                  images: images,
                  index: _bannerIndex,
                  onPageChanged: (value) =>
                      setState(() => _bannerIndex = value),
                );
              },
            ),
            const SizedBox(height: 28),
            _SectionTitle('تتبع الشحنة'.tr),
            const SizedBox(height: 12),
            const _TrackingCard(),
            const SizedBox(height: 28),
            GetBuilder<ProductProvider>(
              builder: (productProvider) {
                final categories = productProvider.categories;

                if (productProvider.isCategoriesLoading && categories.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(
                        color: Color(0xFFE71D24),
                      ),
                    ),
                  );
                }

                if (categories.isEmpty) {
                  return const SizedBox.shrink();
                }

                return _CategoriesProductsSections(
                  categories: categories,
                  onViewMore: (int catId, String catName) => _openPage(
                    CategoryProductsPage(categoryId: catId, pageTitle: catName),
                  ),
                  onOpenProduct: (product) => _openPage(
                    ProductDetailPage(
                      product: Map<String, dynamic>.from(product as Map),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _CategoriesProductsSections extends StatefulWidget {
  const _CategoriesProductsSections({
    required this.categories,
    required this.onViewMore,
    required this.onOpenProduct,
  });

  final List<dynamic> categories;
  final void Function(int categoryId, String categoryName) onViewMore;
  final void Function(dynamic product) onOpenProduct;

  @override
  State<_CategoriesProductsSections> createState() =>
      _CategoriesProductsSectionsState();
}

class _CategoriesProductsSectionsState
    extends State<_CategoriesProductsSections> {
  final Map<int, List<dynamic>> _productsByCategory = {};
  final Map<int, bool> _loadingByCategory = {};

  @override
  void initState() {
    super.initState();
    _loadAllCategories();
  }

  Future<void> _loadAllCategories() async {
    final futures = widget.categories.map((cat) async {
      final id = int.tryParse(cat['id']?.toString() ?? '');
      if (id == null) return;

      setState(() => _loadingByCategory[id] = true);

      try {
        final products = await ApiService.getProducts(
          categoryId: id,
        ).timeout(const Duration(seconds: 8), onTimeout: () => []);
        if (!mounted) return;
        setState(() {
          if (products.isNotEmpty) {
            _productsByCategory[id] = products.take(2).toList();
          }
          _loadingByCategory[id] = false;
        });
      } catch (e) {
        logError('Load products for category $id error: $e');
        if (!mounted) return;
        setState(() => _loadingByCategory[id] = false);
      }
    });

    await Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> sections = [];

    for (final cat in widget.categories) {
      final id = int.tryParse(cat['id']?.toString() ?? '');

      if (id == null) continue;

      final isLoading = _loadingByCategory[id] ?? true;
      final products = _productsByCategory[id];

      if (!isLoading && (products == null || products.isEmpty)) continue;

      final catName = cat['name']?.toString() ?? '';

      sections.add(
        _CategorySection(
          categoryId: id,
          categoryName: catName,
          products: products ?? [],
          isLoading: isLoading,
          onViewMore: () => widget.onViewMore(id, catName),
          onOpenProduct: widget.onOpenProduct,
        ),
      );

      sections.add(const SizedBox(height: 28));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.categoryId,
    required this.categoryName,
    required this.products,
    required this.isLoading,
    required this.onViewMore,
    required this.onOpenProduct,
  });

  final int categoryId;
  final String categoryName;
  final List<dynamic> products;
  final bool isLoading;
  final VoidCallback onViewMore;
  final void Function(dynamic product) onOpenProduct;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _SectionTitle(categoryName),
            GestureDetector(
              onTap: onViewMore,
              child: Row(
                children: const [
                  Text(
                    'عرض المزيد',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE71D24),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: Color(0xFFE71D24),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (isLoading)
          Row(
            children: [
              Expanded(child: ProductCardSkeleton()),
              const SizedBox(width: 12),
              Expanded(child: ProductCardSkeleton()),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (products.isNotEmpty)
                Expanded(
                  child: ProductCard(
                    product: products[0],
                    onTap: () => onOpenProduct(products[0]),
                  ),
                ),
              if (products.length > 1) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ProductCard(
                    product: products[1],
                    onTap: () => onOpenProduct(products[1]),
                  ),
                ),
              ] else if (products.length == 1)
                const Expanded(child: SizedBox()),
            ],
          ),
      ],
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.onTapNotification,
    required this.notificationsFuture,
    required this.onTapDashboard,
  });

  final Future<void> Function() onTapNotification;
  final Future<int> notificationsFuture;
  final VoidCallback onTapDashboard;

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'صباح الخير';
    return 'مساء الخير';
  }

  String _activeShipmentsText(int count) {
    if (count <= 0) return 'ليس لديك شحنات نشطة';
    if (count == 1) return 'لديك شحنة نشطة واحدة';
    return 'لديك $count شحنات نشطة';
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AuthProvider>(
      builder: (auth) {
        return GetBuilder<ShipmentProvider>(
          builder: (shipmentProvider) {
            final userName = auth.displayName;
            final greeting = _timeGreeting();
            final activeShipmentsCount = shipmentProvider.shipments.where((s) {
              final status = (s['current_status'] ?? '')
                  .toString()
                  .toLowerCase();
              return status != 'تم التسليم' &&
                  status != 'delivered' &&
                  status != 'completed';
            }).length;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'مرحباً $userName',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activeShipmentsText(activeShipmentsCount),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => onTapNotification(),
                      child: FutureBuilder<int>(
                        future: notificationsFuture,
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(
                                Icons.notifications_none_rounded,
                                color: Color(0xFF1E293B),
                                size: 28,
                              ),
                              if (count > 0)
                                Positioned(
                                  right: 2,
                                  top: 2,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE71D24),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onTapDashboard,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(
                          Icons.dashboard_rounded,
                          color: Color(0xFF1E293B),
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TopActionsRow extends StatelessWidget {
  const _TopActionsRow({
    required this.onTapDelivery,
    required this.onTapTrack,
    required this.onTapAddress,
    required this.onTapServices,
  });

  final VoidCallback onTapDelivery;
  final VoidCallback onTapTrack;
  final VoidCallback onTapAddress;
  final VoidCallback onTapServices;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActionItem(
          title: 'اطلب توصيل',
          icon: Icons.inventory_2_rounded,
          iconColor: Colors.red.shade600,
          bgColor: Colors.red.shade50,
          onTap: onTapDelivery,
        ),
        _ActionItem(
          title: 'تتبع شحنتك',
          icon: Icons.local_shipping_rounded,
          iconColor: Colors.green.shade600,
          bgColor: Colors.green.shade50,
          onTap: onTapTrack,
        ),
        _ActionItem(
          title: 'اطلب عنوان',
          icon: Icons.location_on_rounded,
          iconColor: Colors.purple.shade600,
          bgColor: Colors.purple.shade50,
          onTap: onTapAddress,
        ),
        _ActionItem(
          title: 'خدمات مالية',
          icon: Icons.account_balance_wallet_rounded,
          iconColor: Colors.orange.shade600,
          bgColor: Colors.orange.shade50,
          onTap: onTapServices,
        ),
      ],
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 82,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSlider extends StatelessWidget {
  const _HeroSlider({
    required this.controller,
    required this.images,
    required this.index,
    required this.onPageChanged,
  });

  final PageController controller;
  final List<String> images;
  final int index;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: PageView.builder(
              controller: controller,
              onPageChanged: onPageChanged,
              itemCount: images.length,
              itemBuilder: (context, i) {
                return CachedImage(
                  imageUrl: images[i],
                  fit: BoxFit.cover,
                  width: double.infinity,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(images.length, (i) {
            final active = i == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFE71D24)
                    : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      textAlign: TextAlign.right,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        color: Color(0xFF1E293B),
      ),
    );
  }
}

class _TrackingCard extends StatefulWidget {
  const _TrackingCard();

  @override
  State<_TrackingCard> createState() => _TrackingCardState();
}

class _TrackingCardState extends State<_TrackingCard> {
  late final TextEditingController _trackingController;

  @override
  void initState() {
    super.initState();
    _trackingController = TextEditingController();
  }

  @override
  void dispose() {
    _trackingController.dispose();
    super.dispose();
  }

  void _openTracking() {
    final number = _trackingController.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            TrackPage(initialTrackingNumber: number.isEmpty ? null : number),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _trackingController,
                onSubmitted: (_) => _openTracking(),
                textAlignVertical: TextAlignVertical.center,
                decoration: const InputDecoration(
                  hintText: 'أدخل رقم التتبع',
                  hintStyle: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _openTracking,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE71D24),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
              elevation: 0,
            ),
            child: Text(
              'تتبع'.tr,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
