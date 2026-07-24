import 'package:flutter/material.dart';
import 'package:online_ezzy/core/localization/app_translations.dart';
import 'package:online_ezzy/core/services/api_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<NotificationItem>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    _notificationsFuture = ApiService.getNotifications().then(
      (data) => data.map((json) => NotificationItem.fromJson(json)).toList(),
    );
  }

  Future<void> _refreshNotifications() async {
    setState(() {
      _loadNotifications();
    });
    await _notificationsFuture;
  }

  Future<void> _markAsRead(String id) async {
    final success = await ApiService.markNotificationAsRead(id);
    if (!mounted) return;

    if (success) {
      _refreshNotifications();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تحديث الإشعار'.tr)));
    }
  }

  String _getErrorMessage(Object? error) {
    final message = error?.toString().toLowerCase() ?? '';
    if (message.contains('401') ||
        message.contains('403') ||
        message.contains('token')) {
      return 'لم نتمكن من تحميل الإشعارات. تأكد من تسجيل الدخول ثم اسحب للتحديث.'
          .tr;
    }
    return 'تعذر تحميل الإشعارات الآن. اسحب للتحديث.'.tr;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: Text(
        'الإشعارات'.tr,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBody() {
    return FutureBuilder<List<NotificationItem>>(
      future: _notificationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error);
        }

        final notifications = snapshot.data ?? [];
        if (notifications.isEmpty) {
          return _buildEmptyView();
        }

        return RefreshIndicator(
          onRefresh: _refreshNotifications,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) => _NotificationCard(
              notification: notifications[index],
              onMarkAsRead: _markAsRead,
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorView(Object? error) {
    return RefreshIndicator(
      onRefresh: _refreshNotifications,
      child: ListView(
        children: [
          const SizedBox(height: 130),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _getErrorMessage(error),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return RefreshIndicator(
      onRefresh: _refreshNotifications,
      child: ListView(
        children: [
          const SizedBox(height: 150),
          Center(
            child: Text(
              'لا توجد إشعارات حالياً'.tr,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

// Separate model class
class NotificationItem {
  final String id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'إشعار جديد'.tr,
      message: json['message']?.toString() ?? '',
      isRead: json['is_read'] == true,
      createdAt: _parseDate(json['created_at']),
    );
  }

  static DateTime _parseDate(String? dateStr) {
    if (dateStr == null) return DateTime.now();
    return DateTime.tryParse(dateStr) ?? DateTime.now();
  }

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inDays > 0) return '${diff.inDays} يوم مضى';
    if (diff.inHours > 0) return '${diff.inHours} ساعة مضت';
    if (diff.inMinutes > 0) return '${diff.inMinutes} دقيقة مضت';
    return 'الآن';
  }
}

// Separate widget for notification card
class _NotificationCard extends StatelessWidget {
  final NotificationItem notification;
  final Function(String) onMarkAsRead;

  const _NotificationCard({
    required this.notification,
    required this.onMarkAsRead,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: notification.isRead ? null : () => onMarkAsRead(notification.id),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead
                ? Colors.white
                : Colors.red.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead
                  ? Colors.grey.shade200
                  : Colors.red.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIcon(),
              const SizedBox(width: 16),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE71D24).withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.notifications_none,
        color: Color(0xFFE71D24),
        size: 24,
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 8),
        _buildMessage(),
        if (!notification.isRead) _buildUnreadHint(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            notification.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        Text(
          notification.formattedTime,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  Widget _buildMessage() {
    return Text(
      notification.message,
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF64748B),
        height: 1.5,
      ),
    );
  }

  Widget _buildUnreadHint() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        'اضغط للتحديد كمقروء'.tr,
        style: const TextStyle(
          color: Color(0xFFE71D24),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
