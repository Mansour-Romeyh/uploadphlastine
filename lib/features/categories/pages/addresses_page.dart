import 'package:flutter/material.dart';
import 'package:online_ezzy/core/localization/get_x_import.dart';
import 'package:online_ezzy/core/widgets/category_card.dart';
import 'package:online_ezzy/core/widgets/empty_state.dart';
import 'package:online_ezzy/features/categories/controllers/product_provider.dart';
import 'package:online_ezzy/features/dashboard/pages/category_products_page.dart';

class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<ProductProvider>().loadCategories();
    });
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
          title: const Text(
            'العناوين',
            style: TextStyle(
              color: Color(0xFF1E3A5F),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: GetBuilder<ProductProvider>(
          builder: (provider) {
            if (provider.isCategoriesLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFE71D24)),
              );
            }

            final categories = provider.categories;

            final filteredCategories = categories.where((category) {
              final count = category['count'] ?? 0;
              final productCount = int.tryParse(count.toString()) ?? 0;
              return productCount > 0 &&
                  category['name']?.toString().contains('عنوان') == true;
            }).toList();

            if (filteredCategories.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.category_outlined,
                title: 'لا توجد تصنيفات متاحة',
                subtitle: 'جميع التصنيفات فارغة حالياً',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredCategories.length,
              itemBuilder: (context, index) {
                final category = filteredCategories[index];
                final id = category['id']?.toString() ?? '';
                final name = category['name']?.toString() ?? 'تصنيف';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: CategoryCard(
                    category: category,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CategoryProductsPage(
                            categoryId: int.tryParse(id) ?? 0,
                            pageTitle: name,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
