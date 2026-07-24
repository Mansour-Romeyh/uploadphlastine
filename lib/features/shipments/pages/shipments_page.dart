import 'package:flutter/material.dart';
import 'package:online_ezzy/core/localization/app_translations.dart';
import 'package:online_ezzy/core/localization/get_x_import.dart';
import 'package:online_ezzy/core/services/api_service.dart';
import 'package:online_ezzy/core/utils/image_url_utils.dart';
import 'package:online_ezzy/core/widgets/cached_image.dart';
import 'package:online_ezzy/features/auth/pages/login_page.dart';
import 'package:online_ezzy/features/dashboard/pages/notifications_page.dart';
import 'package:online_ezzy/features/shipments/controllers/shipment_provider.dart';

class ShipmentsPage extends StatefulWidget {
  const ShipmentsPage({super.key});

  @override
  State<ShipmentsPage> createState() => _ShipmentsPageState();
}

class _ShipmentsPageState extends State<ShipmentsPage> {
  String _selectedFilter = 'الكل';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filters = [
    'الكل',
    'في الصندوق',
    'في الطريق',
    'تم التسليم',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<ShipmentProvider>().loadShipments();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Maps every possible API status value to the Arabic display label used in filters.
  static String _normalizeStatus(String raw) {
    final s = raw.trim();
    if (s == 'تم التسليم') return 'تم التسليم';
    if (s == 'في الطريق') return 'في الطريق';
    return 'في الصندوق';
  }

  Color _statusColor(String status) {
    final n = _normalizeStatus(status);
    if (n == 'تم التسليم') return const Color(0xFF10B981);
    if (n == 'في الطريق') return const Color(0xFFF59E0B);
    return const Color(0xFF3B82F6);
  }

  int _statusStep(String status) {
    final n = _normalizeStatus(status);
    if (n == 'تم التسليم') return 3;
    if (n == 'في الطريق') return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          // ← زر الرجوع
          leading: BackButton(),

          title: const Text(
            'الشحنات',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          // ← أيقونة الإشعارات + البحث في actions
          actions: [
            FutureBuilder<int>(
              future: ApiService.getUnreadNotificationsCount(),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_none,
                        color: Color(0xFF475569),
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsPage(),
                          ),
                        );
                        setState(
                          () {},
                        ); // يعيد بناء الـ FutureBuilder لتحديث العداد
                      },
                    ),
                    if (count > 0)
                      Positioned(
                        top: 12,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE71D24),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        body: GetBuilder<ShipmentProvider>(
          builder: (shipmentProvider) {
            final allShipments = shipmentProvider.shipments;
            final query = _searchController.text.trim().toLowerCase();

            final filtered = allShipments.where((shipment) {
              final tracking = shipment['tracking_number']?.toString() ?? '';
              // Use whichever key the API returns; normalize to Arabic label
              final rawStatus = (shipment['status'] ?? '').toString();
              final normalizedStatus = _normalizeStatus(rawStatus);

              final filterMatches =
                  _selectedFilter == 'الكل' ||
                  normalizedStatus == _selectedFilter;
              final searchMatches =
                  query.isEmpty || tracking.toLowerCase().contains(query);
              return filterMatches && searchMatches;
            }).toList();

            return Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: _filters.map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: ChoiceChip(
                            label: Text(
                              filter,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedFilter = filter);
                              }
                            },
                            showCheckmark: false,
                            selectedColor: const Color(0xFFE71D24),
                            backgroundColor: const Color(0xFFF1F5F9),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'ابحث برقم الشحنة'.tr,
                      hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                Expanded(
                  child: shipmentProvider.isLoading && allShipments.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : shipmentProvider.requiresAuth
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.lock_outline,
                                  size: 64,
                                  color: Color(0xFF94A3B8),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'يجب تسجيل الدخول'.tr,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'قم بتسجيل الدخول لعرض شحناتك'.tr,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LoginPage(),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFFE71D24),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    'تسجيل الدخول'.tr,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: shipmentProvider.loadShipments,
                          child: filtered.isEmpty
                              ? ListView(
                                  children: [
                                    const SizedBox(height: 80),
                                    Center(
                                      child: Column(
                                        children: [
                                          Text(
                                            'لا توجد شحنات حاليا'.tr,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'ابدأ بطلب توصيل جديد'.tr,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filtered.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 16),
                                  itemBuilder: (context, index) {
                                    final shipment = filtered[index];
                                    final tracking =
                                        shipment['tracking_number']
                                            ?.toString() ??
                                        '';
                                    final rawStatus =
                                        (shipment['status'] ??
                                                shipment['current_status'] ??
                                                '')
                                            .toString();
                                    final status = _normalizeStatus(rawStatus);

                                    final statusColor = _statusColor(status);
                                    final step = _statusStep(status);

                                    final date =
                                        shipment['date']?.toString() ?? '';
                                    final imageUrl = shipmentImageUrl(shipment);

                                    return _ShipmentCard(
                                      trackingNumber: tracking,
                                      status: status,
                                      statusColor: statusColor,
                                      imageUrl: imageUrl,
                                      step: step,
                                      date: date,
                                    );
                                  },
                                ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ShipmentCard extends StatelessWidget {
  final String trackingNumber;
  final String status;
  final Color statusColor;
  final String imageUrl;
  final int step;
  final String date;

  const _ShipmentCard({
    required this.trackingNumber,
    required this.status,
    required this.statusColor,
    required this.imageUrl,
    required this.step,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final canOpenImage = imageUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: canOpenImage
                    ? () => _showZoomableImage(context, imageUrl)
                    : null,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedImage(
                        imageUrl: imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (canOpenImage)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.zoom_in,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رقم التتبع : $trackingNumber'.tr,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.5),
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          _buildTimeline(step),
          SizedBox(height: 24),
          Row(
            children: [
              const Spacer(),
              Text(
                'تاريخ $date'.tr,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showZoomableImage(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return GestureDetector(
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 5.0,
                      panEnabled: true,
                      child: CachedImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        width: MediaQuery.of(dialogContext).size.width,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeline(int step) {
    Color activeRed = const Color(0xFFE71D24);
    Color inactiveGrey = const Color(0xFFE2E8F0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 11,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 2,
                      color: step >= 2 ? activeRed : inactiveGrey,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: step >= 3 ? activeRed : inactiveGrey,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTimelineNode(
                  title: 'في الصندوق',
                  state: 1,
                  activeColor: activeRed,
                  inactiveColor: inactiveGrey,
                ),
                _buildTimelineNode(
                  title: 'في الطريق',
                  state: step >= 2 ? 2 : 0,
                  activeColor: activeRed,
                  inactiveColor: inactiveGrey,
                ),
                _buildTimelineNode(
                  title: 'تم التسليم',
                  state: step >= 3 ? 2 : 0,
                  activeColor: activeRed,
                  inactiveColor: inactiveGrey,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimelineNode({
    required String title,
    required int state,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    Widget circle;
    if (state == 1) {
      circle = Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: activeColor, shape: BoxShape.circle),
        child: Icon(Icons.check, color: Colors.white, size: 16),
      );
    } else if (state == 2) {
      circle = Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: activeColor, width: 2),
        ),
        child: Center(
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: activeColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    } else {
      circle = Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: inactiveColor, width: 2),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: inactiveColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        circle,
        SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
