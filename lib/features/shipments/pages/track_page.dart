import 'package:flutter/material.dart';
import 'package:online_ezzy/core/localization/app_translations.dart';
import 'package:online_ezzy/core/localization/get_x_import.dart';
import 'package:online_ezzy/core/utils/image_url_utils.dart';
import 'package:online_ezzy/core/widgets/cached_image.dart';
import 'package:online_ezzy/features/shipments/controllers/shipment_provider.dart';

class TrackPage extends StatefulWidget {
  const TrackPage({super.key, this.initialTrackingNumber});
  final String? initialTrackingNumber;

  @override
  State<TrackPage> createState() => _TrackPageState();
}

class _TrackPageState extends State<TrackPage> {
  late final TextEditingController _trackingController;
  Map<String, dynamic>? _trackingData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _trackingController = TextEditingController(
      text: widget.initialTrackingNumber ?? '',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if ((widget.initialTrackingNumber ?? '').trim().isNotEmpty) {
        _trackShipment();
      }
    });
  }

  @override
  void dispose() {
    _trackingController.dispose();
    super.dispose();
  }

  Future<void> _trackShipment() async {
    final number = _trackingController.text.trim();
    if (number.isEmpty) {
      setState(() {
        _error = 'برجاء إدخال رقم الشحنة'.tr;
        _trackingData = null;
      });
      return;
    }
    setState(() => _error = null);
    final result = await Get.find<ShipmentProvider>().trackShipment(number);
    if (!mounted) return;
    if (result == null || result.isEmpty) {
      setState(() {
        _trackingData = null;
        _error = 'تعذر العثور على الشحنة'.tr;
      });
      return;
    }
    setState(() {
      _trackingData = result;
      _error = null;
    });
  }

  void _showZoomableImage(String imageUrl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 5.0,
                    child: CachedImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      width: MediaQuery.of(ctx).size.width,
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_TimelineItem> _buildTimeline(Map<String, dynamic> data) {
    final history = data['status_history'];
    if (history is! List || history.isEmpty) return const [];
    return history
        .whereType<Map>()
        .map(
          (e) => _TimelineItem(
            e['status']?.toString() ?? 'تحديث الشحنة'.tr,
            e['changed_at']?.toString() ?? '',
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ShipmentProvider>(
      builder: (shipment) {
        final isLoading = shipment.isLoading;
        final data = _trackingData;
        final timeline = data == null
            ? <_TimelineItem>[]
            : _buildTimeline(data);
        final progress = timeline.isEmpty
            ? 0.0
            : (timeline.length / timeline.length).clamp(0.0, 1.0);
        final trackingNumber =
            data?['tracking_number']?.toString() ??
            _trackingController.text.trim();
        final status = data?['current_status']?.toString() ?? '';
        final eta = data?['date_added']?.toString() ?? '';
        final imageUrl = data != null
            ? normalizeImageUrl(data['image_url'])
            : '';

        return Scaffold(
          backgroundColor: const Color(0xFFF5F6FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: const BackButton(),
            title: Text(
              'تتبع الشحنة'.tr,
              style: const TextStyle(
                color: Color(0xFF1E3A5F),
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── حقل البحث ──
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
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رقم الشحنة'.tr,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _trackingController,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _trackShipment(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1E3A5F),
                            ),
                            decoration: InputDecoration(
                              hintText: 'مثال: EZ-94012'.tr,
                              hintStyle: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.numbers_rounded,
                                size: 18,
                                color: Color(0xFF94A3B8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: isLoading ? null : _trackShipment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE71D24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 13,
                            ),
                            elevation: 0,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'تتبع'.tr,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── خطأ ──
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFB91C1C),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── نتيجة التتبع ──
              if (data != null) ...[
                const SizedBox(height: 16),

                // صورة الشحنة
                if (imageUrl.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => _showZoomableImage(imageUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        alignment: Alignment.bottomLeft,
                        children: [
                          CachedImage(
                            imageUrl: imageUrl,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.zoom_in,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // كارد الحالة
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'رقم الشحنة'.tr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          Text(
                            trackingNumber,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A5F),
                            ),
                          ),
                        ],
                      ),
                      if (status.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الحالة'.tr,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFE71D24,
                                ).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFE71D24),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (eta.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'التاريخ'.tr,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            Text(
                              eta,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFEEF0F3),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFFE71D24),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}% مكتمل'.tr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),

                // الخط الزمني
                if (timeline.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'مسار الشحنة'.tr,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                      children: [
                        for (int i = 0; i < timeline.length; i++)
                          _TimelineTile(
                            item: timeline[i],
                            isLast: i == timeline.length - 1,
                          ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      'لا يوجد خط زمني متاح'.tr,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineItem {
  const _TimelineItem(this.title, this.subtitle);
  final String title;
  final String subtitle;
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.item, required this.isLast});
  final _TimelineItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Color(0xFFE71D24),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 10, color: Colors.white),
            ),
            if (!isLast)
              Container(width: 2, height: 48, color: const Color(0xFFEEF0F3)),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
