import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:online_ezzy/core/localization/app_translations.dart';
import 'package:online_ezzy/core/localization/get_x_import.dart';
import 'package:online_ezzy/core/services/api_service.dart';
import 'package:online_ezzy/features/auth/controllers/auth_provider.dart';
import 'package:online_ezzy/features/auth/pages/change_password_page.dart';
import 'package:online_ezzy/features/auth/pages/login_page.dart';
import 'package:online_ezzy/features/dashboard/controllers/dashboard_provider.dart';
import 'package:online_ezzy/features/dashboard/pages/shell_page.dart';
import 'package:online_ezzy/features/shipments/controllers/shipment_provider.dart';

import 'edit_profile_page.dart';
import 'web_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _notificationsEnabled = true;
  bool _showMainView = true;

  List<Map<String, dynamic>> _customerOrders = [];
  bool _isOrdersLoading = false;
  String? _ordersError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      Get.find<DashboardProvider>().loadData(),
      Get.find<ShipmentProvider>().loadShipments(),
    ]);
    await _loadOrders();
  }

  Future<void> _loadOrders() async {
    final auth = Get.find<AuthProvider>();
    final localOrders = await _loadLocalSuccessOrders();

    final userId = AuthProvider.extractUserId(auth.userData);
    if (!auth.isAuthenticated || userId == null) {
      if (!mounted) return;
      setState(() {
        _customerOrders = localOrders;
        _isOrdersLoading = false;
      });
      return;
    }

    setState(() => _isOrdersLoading = true);
    try {
      final orders = await ApiService.getCustomerOrders(userId);
      if (!mounted) return;
      setState(() => _customerOrders = _mergeOrders(localOrders, orders));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _customerOrders = localOrders;
        _ordersError = 'تعذر تحميل الطلبات';
      });
    } finally {
      if (!mounted) return;
      setState(() => _isOrdersLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadLocalSuccessOrders() async {
    final raw = GetStorage().read<String>('local_success_orders');
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> _mergeOrders(
    List<Map<String, dynamic>> local,
    List<Map<String, dynamic>> remote,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    for (final item in [...local, ...remote]) {
      final id = _safeText(item['id']);

      if (id.isNotEmpty) byId[id] = item;
    }
    final merged = byId.values.toList();
    merged.sort((a, b) {
      final aDate =
          DateTime.tryParse(a['date_created']?.toString() ?? '') ?? DateTime(0);
      final bDate =
          DateTime.tryParse(b['date_created']?.toString() ?? '') ?? DateTime(0);
      return bDate.compareTo(aDate);
    });
    return merged;
  }

  String _safeText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return (text.isEmpty || text.toLowerCase() == 'null') ? '' : text;
  }

  String _orderStatusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return 'بانتظار الدفع';
      case 'processing':
        return 'قيد المعالجة';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      case 'failed':
        return 'فشل';
      case 'on-hold':
        return 'معلق';
      case 'refunded':
        return 'مسترجع';
      default:
        return status.isEmpty ? 'غير معروف' : status;
    }
  }

  String _formatOrderDate(dynamic rawDate) {
    final parsed = DateTime.tryParse(rawDate?.toString() ?? '');
    if (parsed == null) return '-';
    final d = parsed.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  List<Map<String, dynamic>> _resolveCustomerAddresses(AuthProvider auth) {
    final user = auth.userData;
    if (user == null) return [];
    final result = <Map<String, dynamic>>[];

    void addAddress(String title, dynamic source, bool isDefault) {
      if (source is! Map) return;
      final firstName = _safeText(source['first_name']);
      final lastName = _safeText(source['last_name']);
      final fullName = '$firstName $lastName'.trim();
      final line = [
        _safeText(source['address_1']),
        _safeText(source['address_2']),
      ].where((v) => v.isNotEmpty).join(' - ');
      final city = [
        _safeText(source['city']),
        _safeText(source['state']),
        _safeText(source['country']),
      ].where((v) => v.isNotEmpty).join(' - ');
      final phone = _safeText(source['phone']);
      if (fullName.isEmpty && line.isEmpty && city.isEmpty) return;
      result.add({
        'title': title,
        'fullName': fullName.isNotEmpty ? fullName : auth.displayName,
        'addressLine': line,
        'city': city,
        'phone': phone,
        'isDefault': isDefault,
      });
    }

    addAddress('عنوان الفواتير', user['billing'], true);
    addAddress('عنوان الشحن', user['shipping'], result.isEmpty);
    return result;
  }

  List<Map<String, dynamic>> _resolvePaymentMethodsFromOrders() {
    final methods = <String, Map<String, dynamic>>{};
    for (final order in _customerOrders) {
      final rawTitle = _safeText(
        order['payment_method_title'] ?? order['payment_method'],
      );
      if (rawTitle.isEmpty) continue;
      final key = rawTitle.toLowerCase();
      methods[key] = methods.containsKey(key)
          ? {
              ...methods[key]!,
              'ordersCount': (methods[key]!['ordersCount'] as int) + 1,
            }
          : {'title': rawTitle, 'ordersCount': 1};
    }
    return methods.values.toList();
  }

  void _navigateToTab(int index) {
    setState(() {
      _showMainView = false;
      _tabController.index = index;
    });
  }

  // ── build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const BackButtonIcon(),
            onPressed: () {
              if (!_showMainView) {
                setState(() => _showMainView = true);
              } else {
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.pop();
                } else {
                  nav.pushReplacement(
                    MaterialPageRoute(builder: (_) => const ShellPage()),
                  );
                }
              }
            },
          ),
          title: Text(
            'الإعدادات'.tr,
            style: const TextStyle(
              color: Color(0xFF2C3E50),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          bottom: _showMainView
              ? null
              : TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  indicator: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  tabs: const [
                    Tab(text: 'الطلبات'),
                    Tab(text: 'تفاصيل الطرود'),
                    Tab(text: 'العناوين'),
                    Tab(text: 'طرق الدفع'),
                  ],
                ),
        ),
        body: _showMainView ? _buildMainView() : _buildTabsView(),
      ),
    );
  }

  // ── Main View ─────────────────────────────────────────────

  Widget _buildMainView() {
    final auth = Get.find<AuthProvider>();

    return ListView(
      children: [
        _buildProfileCard(),
        if (auth.isAuthenticated) _buildMembershipCard(),
        if (auth.isAuthenticated) _buildAccountSection(),
        _buildSettingsSection(),
        _buildLogoutButton(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildProfileCard() {
    return Container(
      margin: const EdgeInsets.all(16),
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
      child: GetBuilder<AuthProvider>(
        builder: (auth) {
          return Column(
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 35,
                    child: Icon(Icons.person, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.email_outlined,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                auth.primaryEmail,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    if (auth.isAuthenticated) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfilePage(),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade100),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    auth.isAuthenticated ? 'تعديل البيانات' : 'تسجيل الدخول',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMembershipCard() {
    return GetBuilder<DashboardProvider>(
      builder: (dashProvider) {
        final resolved = dashProvider.dashboardData ?? {};
        final membershipName = resolved['membership'] ?? 'غير متوفر';
        final pointsAvailable = resolved['points_available'] as int?;
        final pointsTotal = resolved['points_total'] as int?;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _MembershipInfoItem(
                  title: 'الباقة الحالية',
                  value: membershipName,
                  icon: Icons.workspace_premium_rounded,
                  color: const Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MembershipInfoItem(
                  title: 'النقاط المتاحة',
                  value: pointsAvailable?.toString() ?? '-',
                  icon: Icons.stars_rounded,
                  color: const Color(0xFF0EA5E9),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MembershipInfoItem(
                  title: 'مجموع النقاط',
                  value: pointsTotal?.toString() ?? '-',
                  icon: Icons.score_rounded,
                  color: const Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountSection() {
    return Container(
      margin: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'حسابي',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          _buildMenuListItem('الطلبات', onTap: () => _navigateToTab(0)),
          const Divider(height: 1, color: Color(0xFFF4F6F9)),
          _buildMenuListItem('تفاصيل الطرود', onTap: () => _navigateToTab(1)),
          const Divider(height: 1, color: Color(0xFFF4F6F9)),
          _buildMenuListItem('العناوين', onTap: () => _navigateToTab(2)),
          const Divider(height: 1, color: Color(0xFFF4F6F9)),
          _buildMenuListItem('طرق الدفع', onTap: () => _navigateToTab(3)),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('إعدادات التطبيق'.tr),
          _buildSwitchTile(
            'الإشعارات'.tr,
            _notificationsEnabled,
            (val) => setState(() => _notificationsEnabled = val),
          ),
          _buildComingSoonTile('تغيير اللغة'.tr, Icons.language),
          const SizedBox(height: 8),
          _buildComingSoonTile('الوضع الليلي'.tr, Icons.dark_mode_outlined),
          const SizedBox(height: 8),
          _buildSectionHeader('المزيد'.tr),
          _buildListTile(
            'تغيير كلمة المرور'.tr,
            Icons.lock_outline,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
            ),
          ),
          _buildListTile(
            'سياسة الخصوصية'.tr,
            Icons.privacy_tip_outlined,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => WebScreen.privacyPolicy()),
            ),
          ),

          _buildListTile(
            'تواصل معنا'.tr,
            Icons.contact_support_outlined,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => WebScreen.contactUs()),
            ),
          ),
          _buildListTile(
            'حول التطبيق'.tr,
            Icons.info_outline,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => WebScreen.aboutApp()),
            ),
            trailing: 'الإصدار 1.0.0'.tr,
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GetBuilder<AuthProvider>(
      builder: (auth) {
        if (!auth.isAuthenticated) return const SizedBox.shrink();
        return Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text(
                      'تسجيل الخروج',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text(
                          'إلغاء',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'موافق',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await auth.logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const ShellPage()),
                    (route) => false,
                  );
                }
              },
              child: const Text(
                'تسجيل الخروج',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Tabs View ─────────────────────────────────────────────

  Widget _buildTabsView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildOrdersTab(),
        _buildShipmentsTab(),
        _buildAddressTab(),
        _buildPaymentMethodsTab(),
      ],
    );
  }

  Widget _buildOrdersTab() {
    if (_isOrdersLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE71D24)),
      );
    }
    if (_customerOrders.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد طلبات بعد',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _customerOrders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final order = _customerOrders[index];
        final orderId = _safeText(order['id']);
        final status = _orderStatusLabel(_safeText(order['status']));
        final total = _safeText(order['total']);
        final currency = _safeText(order['currency']);
        final date = _formatOrderDate(order['date_created']);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'طلب #$orderId',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$total $currency · $date',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShipmentsTab() {
    return GetBuilder<ShipmentProvider>(
      builder: (provider) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFE71D24)),
          );
        }
        if (provider.shipments.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد شحنات بعد',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: provider.shipments.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final s = provider.shipments[index];
            final code = _safeText(
              s['tracking_number'] ?? s['number'] ?? s['id'],
            );
            final status = _safeText(
              s['current_status'] ?? s['status'] ?? s['shipment_status'],
            );

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'رقم التتبع: $code',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (status.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        AppTranslations.preferBoxOverWarehouse(status),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAddressTab() {
    return GetBuilder<AuthProvider>(
      builder: (auth) {
        final addresses = _resolveCustomerAddresses(auth);
        if (addresses.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد عناوين محفوظة',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: addresses.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final addr = addresses[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Color(0xFFE71D24),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        addr['title'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const Spacer(),
                      if (addr['isDefault'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'الأكثر استخداماً',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFFE71D24),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    addr['fullName'] ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                    ),
                  ),
                  if ((addr['addressLine'] ?? '').isNotEmpty)
                    Text(
                      addr['addressLine'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  if ((addr['city'] ?? '').isNotEmpty)
                    Text(
                      addr['city'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  if ((addr['phone'] ?? '').isNotEmpty)
                    Text(
                      addr['phone'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentMethodsTab() {
    final methods = _resolvePaymentMethodsFromOrders();
    if (methods.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد طرق دفع مسجلة',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: methods.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final method = methods[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5E6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.credit_card_rounded,
                  color: Color(0xFFC68A5A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  method['title'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Text(
                '${method['ordersCount']} طلب',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── UI Helpers ────────────────────────────────────────────

  Widget _buildMenuListItem(String title, {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ),
      trailing: const Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey),
      onTap: onTap ?? () {},
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8, top: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        value: value,
        activeThumbColor: Colors.red,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildComingSoonTile(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        enabled: false,
        leading: Icon(icon, color: Colors.grey),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        subtitle: Text(
          'ستتوفر الميزة في تحديث قادم'.tr,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'قريباً'.tr,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(
    String title,
    IconData icon,
    VoidCallback onTap, {
    String? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null)
              Text(
                trailing,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

// ── Membership Info Item ──────────────────────────────────

class _MembershipInfoItem extends StatelessWidget {
  const _MembershipInfoItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
