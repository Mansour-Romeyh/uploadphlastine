import 'package:flutter/material.dart';
import 'package:online_ezzy/core/localization/get_x_import.dart';
import 'package:online_ezzy/core/widgets/empty_state.dart';
import 'package:online_ezzy/core/widgets/product_card.dart';
import 'package:online_ezzy/features/categories/controllers/product_provider.dart';
import 'package:online_ezzy/features/products/pages/product_detail_page.dart';

class CategoryProductsPage extends StatefulWidget {
  const CategoryProductsPage({
    super.key,
    this.categoryId = 68,
    this.pageTitle = 'طلب توصيل',
  });

  final int categoryId;
  final String pageTitle;

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<ProductProvider>().loadDeliveryProducts(
        categoryId: widget.categoryId,
      );
    });
  }

  void _openProduct(dynamic product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailPage(
          product: Map<String, dynamic>.from(product as Map),
        ),
      ),
    );
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
          title: Text(
            widget.pageTitle,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: GetBuilder<ProductProvider>(
          builder: (provider) {
            if (provider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFE71D24)),
              );
            }

            final products = provider.deliveryProducts.where((item) {
              if (item is! Map) return false;
              final cats = item['categories'];
              if (cats is! List) return false;
              return cats.any(
                (c) =>
                    int.tryParse(c['id']?.toString() ?? '') ==
                    widget.categoryId,
              );
            }).toList();

            if (products.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.inventory_2_outlined,
                title: 'لا توجد منتجات',
                subtitle: 'لا توجد منتجات متاحة في هذا القسم حالياً',
                actionLabel: 'إعادة المحاولة',
                onAction: () => Get.find<ProductProvider>()
                    .loadDeliveryProducts(categoryId: widget.categoryId),
              );
            }

            final rows = <Widget>[];
            for (var i = 0; i < products.length; i += 2) {
              rows.add(
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ProductCard(
                        product: products[i],
                        onTap: () => _openProduct(products[i]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (i + 1 < products.length)
                      Expanded(
                        child: ProductCard(
                          product: products[i + 1],
                          onTap: () => _openProduct(products[i + 1]),
                        ),
                      )
                    else
                      const Expanded(child: SizedBox()),
                  ],
                ),
              );
              rows.add(const SizedBox(height: 12));
            }

            return ListView(padding: const EdgeInsets.all(16), children: rows);
          },
        ),
      ),
    );
  }
}
