import 'package:flutter/material.dart';
import 'package:online_ezzy/core/localization/get_x_import.dart';
import 'package:online_ezzy/core/services/api_service.dart';
import 'package:online_ezzy/core/widgets/cached_image.dart';
import 'package:online_ezzy/features/cart/controllers/cart_provider.dart';
import 'package:online_ezzy/features/cart/pages/cart_page.dart';
import 'package:online_ezzy/features/settings/controllers/settings_provider.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.product});

  final Map<String, dynamic> product;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _VariationOption {
  const _VariationOption({
    required this.id,
    required this.label,
    required this.price,
  });
  final int id;
  final String label;
  final double price;
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late final bool _isVariable;
  late final int _productId;
  late Future<List<_VariationOption>>? _variationsFuture;
  int? _selectedVariationId;

  @override
  void initState() {
    super.initState();
    _productId = int.tryParse(widget.product['id']?.toString() ?? '') ?? 0;
    _isVariable = widget.product['type']?.toString() == 'variable';
    _variationsFuture = _isVariable ? _loadVariations() : null;
  }

  Future<List<_VariationOption>> _loadVariations() async {
    final raw = await ApiService.getProductVariations(_productId);
    final options = <_VariationOption>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final id = int.tryParse(row['id']?.toString() ?? '');
      if (id == null || id <= 0) continue;
      if ((row['status']?.toString().toLowerCase() ?? '') != 'publish') {
        continue;
      }
      if (row['purchasable'] == false) continue;

      final attrs = row['attributes'];
      String label = '';
      if (attrs is List) {
        label = attrs
            .whereType<Map>()
            .map((a) => a['option']?.toString().trim() ?? '')
            .where((v) => v.isNotEmpty)
            .join(' / ');
      }
      if (label.isEmpty) label = row['name']?.toString().trim() ?? 'خيار';

      final priceRaw =
          row['price'] ?? row['regular_price'] ?? row['sale_price'];
      final price =
          double.tryParse(
            priceRaw?.toString().trim().replaceAll(',', '.') ?? '',
          ) ??
          0;

      options.add(_VariationOption(id: id, label: label, price: price));
    }
    if (options.isNotEmpty) {
      _selectedVariationId ??= options.first.id;
    }
    return options;
  }

  double _parsePrice(dynamic v) {
    final p = double.tryParse(v?.toString().trim().replaceAll(',', '.') ?? '');
    return (p == null || p.isNaN || p.isInfinite || p < 0) ? 0 : p;
  }

  String _formatCurrency(double v, SettingsProvider s) {
    final str = v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    return '$str ${s.currencySymbol}';
  }

  String? _imageUrl() {
    final images = widget.product['images'];
    if (images is! List) return null;
    return images
            .whereType<String>()
            .firstWhere((s) => s.startsWith('http'), orElse: () => '')
            .isEmpty
        ? null
        : images.whereType<String>().first;
  }

  Future<void> _showVariationPicker(List<_VariationOption> options) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'اختر العرض',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: options
                    .map(
                      (o) => ListTile(
                        title: Text(o.label),
                        trailing: Text(
                          _formatCurrency(
                            o.price,
                            Get.find<SettingsProvider>(),
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE71D24),
                          ),
                        ),
                        selected: o.id == _selectedVariationId,
                        selectedTileColor: const Color(0xFFFFF1F2),
                        onTap: () => Navigator.of(ctx).pop(o.id),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedVariationId = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.product['name']?.toString() ?? '';
    final basePrice = _parsePrice(widget.product['price']);
    final imageUrl = _imageUrl();
    String desc = widget.product['description']?.toString() ?? '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        // الأزرار الثابتة في نهاية الشاشة
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: _CartButtons(
              productId: _productId,
              basePrice: basePrice,
              isVariable: _isVariable,
              selectedVariationId: _selectedVariationId,
              variationsFuture: _variationsFuture,
              formatCurrency: _formatCurrency,
            ),
          ),
        ),
        body: CustomScrollView(
          slivers: [
            // Header image + back button
            SliverAppBar(
              expandedHeight: 350,
              pinned: true,
              backgroundColor: Colors.white,
              leading: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF1E293B),
                    size: 18,
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: imageUrl != null
                    ? CachedImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: Color(0xFFCBD5E1),
                          size: 80,
                        ),
                      ),
              ),
            ),

            // Product details
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title + price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GetBuilder<SettingsProvider>(
                          builder: (settings) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _isVariable
                                  ? 'من ${_formatCurrency(basePrice, settings)}'
                                  : _formatCurrency(basePrice, settings),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFE71D24),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Variation picker (for variable products) - تم نقله للأعلى
                    if (_isVariable) ...[
                      const SizedBox(height: 20),
                      FutureBuilder<List<_VariationOption>>(
                        future: _variationsFuture,
                        builder: (context, snapshot) {
                          final options =
                              snapshot.data ?? const <_VariationOption>[];
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              options.isEmpty) {
                            return const LinearProgressIndicator(
                              color: Color(0xFFE71D24),
                            );
                          }
                          if (options.isEmpty) return const SizedBox.shrink();

                          final selected = options.firstWhere(
                            (o) => o.id == _selectedVariationId,
                            orElse: () => options.first,
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'العروض المتاحة:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              GetBuilder<SettingsProvider>(
                                builder: (settings) => InkWell(
                                  onTap: () => _showVariationPicker(options),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  selected.label,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                '·',
                                                style: TextStyle(
                                                  color: Color(0xFF94A3B8),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _formatCurrency(
                                                  selected.price,
                                                  settings,
                                                ),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                  color: Color(0xFFE71D24),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: Color(0xFF64748B),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],

                    // Description - تم نقله للأسفل
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 0),
                      // إظهار الوصف كاملاً بدون قيود
                      Text(
                        desc,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF475569),
                          height: 1.7,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartButtons extends StatelessWidget {
  const _CartButtons({
    required this.productId,
    required this.basePrice,
    required this.isVariable,
    required this.selectedVariationId,
    required this.variationsFuture,
    required this.formatCurrency,
  });

  final int productId;
  final double basePrice;
  final bool isVariable;
  final int? selectedVariationId;
  final Future<List<dynamic>>? variationsFuture;
  final String Function(double, SettingsProvider) formatCurrency;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CartProvider>(
      builder: (cart) {
        final cartItem = cart.cartItems.cast<dynamic>().firstWhere((item) {
          if (item is! Map) return false;
          final itemId = int.tryParse(item['id']?.toString() ?? '');
          if (itemId == null) return false;
          if (!isVariable) return itemId == productId;
          if (selectedVariationId != null && selectedVariationId! > 0) {
            final varId = int.tryParse(item['variation_id']?.toString() ?? '');
            return itemId == selectedVariationId ||
                varId == selectedVariationId;
          }
          return itemId == productId;
        }, orElse: () => null);

        final qty = cartItem is Map
            ? () {
                final q = cartItem['quantity'];
                if (q is Map) {
                  return int.tryParse((q['value'] ?? '0').toString()) ?? 0;
                }
                return int.tryParse(q?.toString() ?? '0') ?? 0;
              }()
            : 0;

        final isInCart = qty > 0;
        final isAdding = cart.isAddingProduct(productId) || cart.isLoading;
        final needsVariation =
            isVariable &&
            (selectedVariationId == null || selectedVariationId! <= 0);

        // إعداد زر إضافة إلى السلة كمتغير لاستخدامه في الحالتين
        Widget addToCartButton = ElevatedButton.icon(
          onPressed: isAdding || needsVariation
              ? null
              : () async {
                  if (isInCart) {
                    Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (_) => CartPage()));
                    return;
                  }
                  final success = await cart.addToCart(
                    productId,
                    1,
                    variationId: isVariable ? selectedVariationId : null,
                  );
                  if (!context.mounted || success) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('فشل إضافة المنتج للسلة'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: isInCart
                ? const Color(0xFF10B981) // أخضر
                : const Color(0xFFE71D24), // أحمر
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            // تقليل الحواف الجانبية لتفادي قص النص في الشاشات الصغيرة
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          icon: isAdding
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Icon(
                  isInCart
                      ? Icons.shopping_cart_checkout_rounded
                      : Icons.add_shopping_cart_rounded,
                  size: 20,
                ),
          label: Text(
            isAdding
                ? ''
                : isInCart
                ? 'في السلة، اذهب للسلة'
                : needsVariation
                ? 'اختر العرض'
                : 'أضف للسلة',
            style: TextStyle(
              fontSize: isInCart ? 15 : 13,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );

        // الحالة الأولى: المنتج في السلة -> الزر يأخذ كامل العرض
        if (isInCart) {
          return SizedBox(
            height: 52,
            width: double.infinity,
            child: addToCartButton,
          );
        }

        // الحالة الثانية: المنتج ليس في السلة -> زرين متساويين 50%
        return Row(
          children: [
            Expanded(child: SizedBox(height: 52, child: addToCartButton)),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: isAdding || needsVariation
                      ? null
                      : () async {
                          final success = await cart.addToCart(
                            productId,
                            1,
                            variationId: isVariable
                                ? selectedVariationId
                                : null,
                          );
                          if (!success) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('فشل إضافة المنتج للسلة'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            return;
                          }
                          await Future.delayed(
                            const Duration(milliseconds: 300),
                          );
                          if (context.mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => CartPage()),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B), // لون داكن بارز
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  icon: const Icon(Icons.plus_one, size: 20),
                  label: const Text(
                    'أطلب الآن',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
