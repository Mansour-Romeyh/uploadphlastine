import 'package:flutter/material.dart';
import 'package:online_ezzy/core/localization/app_translations.dart';
import 'package:online_ezzy/core/localization/get_x_import.dart';
import 'package:online_ezzy/core/utils/image_url_utils.dart';
import 'package:online_ezzy/core/widgets/cached_image.dart';
import 'package:online_ezzy/features/shipments/controllers/shipment_provider.dart';

class ShipmentDetailsPage extends StatefulWidget {
  final String trackingNumber;
  final String status;
  final String date;
  final String imageUrl;

  const ShipmentDetailsPage({
    super.key,
    required this.trackingNumber,
    required this.status,
    required this.date,
    this.imageUrl = '',
  });

  @override
  State<ShipmentDetailsPage> createState() => _ShipmentDetailsPageState();
}

class _ShipmentDetailsPageState extends State<ShipmentDetailsPage> {
  Map<String, dynamic>? _details;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchDetails();
    });
  }

  Future<void> _fetchDetails() async {
    final provider = Get.find<ShipmentProvider>();
    Map<String, dynamic>? data;
    try {
      data = await provider
          .getShipmentDetails(widget.trackingNumber)
          .timeout(const Duration(seconds: 12));
    } catch (_) {}
    if (mounted) {
      setState(() {
        _details = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    final imageUrl = details != null
        ? normalizeImageUrl(details['image_url'])
        : normalizeImageUrl(widget.imageUrl);
    final status = details?['current_status']?.toString() ?? widget.status;
    final trackingNumber = details?['tracking_number']?.toString() ?? widget.trackingNumber;

    final history = details?['status_history'];
    final historyList = history is List ? history : <dynamic>[];
    final lastEntry = historyList.isNotEmpty ? historyList.last : null;
    final lastUpdate = lastEntry is Map
        ? lastEntry['changed_at']?.toString()
        : details?['date_added']?.toString() ?? widget.date;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Text(
            'تفاصيل الشحنة'.tr,
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading) ...[
                const LinearProgressIndicator(color: Color(0xFFE71D24), minHeight: 2),
                const SizedBox(height: 12),
              ],
              // Header card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedImage(
                        imageUrl: imageUrl,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'رقم التتبع'.tr,
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              ),
                              SizedBox(height: 4),
                              Text(
                                trackingNumber,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE71D24).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFE71D24).withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              color: Color(0xFFE71D24),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // Timeline card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حالة الشحنة'.tr,
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 24),
                    if (historyList.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          'لا يوجد خط زمني متاح لهذه الشحنة حالياً'.tr,
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      )
                    else
                      ...historyList.asMap().entries.map((entry) {
                        final item = entry.value;
                        if (item is! Map) return const SizedBox.shrink();
                        final title = item['status']?.toString() ?? '';
                        final date = item['changed_at']?.toString() ?? '';
                        final isLast = entry.key == historyList.length - 1;
                        return _buildTimelineStep(
                          title: title,
                          date: date,
                          isLast: isLast,
                        );
                      }),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // Details card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'معلومات إضافية'.tr,
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    const Divider(height: 30, color: Color(0xFFF1F5F9)),
                    _buildDetailRow('تاريخ التحديث'.tr, lastUpdate ?? widget.date),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE71D24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'تتبع حي'.tr,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String date,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFE71D24),
                border: Border.all(color: const Color(0xFFE71D24), width: 2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, size: 14, color: Colors.white),
            ),
            if (!isLast)
              Container(width: 2, height: 40, color: const Color(0xFFE71D24)),
          ],
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
              ),
              if (date.isNotEmpty) ...[
                SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
              SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
