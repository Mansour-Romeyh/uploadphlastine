import 'package:flutter/material.dart';
import 'package:online_ezzy/core/widgets/cached_image.dart';

class CategoryCard extends StatelessWidget {
  final dynamic category;
  final VoidCallback? onTap;

  const CategoryCard({super.key, required this.category, this.onTap});

  @override
  Widget build(BuildContext context) {
    final id = category['id']?.toString() ?? '';

    final name = category['name']?.toString() ?? 'تصنيف';
    final description = category['description']?.toString() ?? '';
    final imageUrl = _extractImageUrl(category);

    final rawCount = category['count'] ?? 0;
    final productCount = int.tryParse(rawCount.toString()) ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(16),
              ),
              child: CachedImage(
                imageUrl: imageUrl,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorWidget: Container(
                  width: 100,
                  height: 100,
                  color: const Color(0xFFF1F5F9),
                  child: Icon(
                    Icons.category,
                    size: 40,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE71D24,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getProductCountText(productCount),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFE71D24),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE71D24),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getProductCountText(int count) {
    if (count == 0) return 'لا توجد منتجات';
    if (count == 1) return 'منتج واحد';
    if (count == 2) return 'منتجين';
    if (count >= 3 && count <= 10) return '$count منتجات';
    return '$count منتج';
  }

  String _extractImageUrl(dynamic category) {
    if (category == null) return '';

    final image = category['image'];
    if (image is Map) {
      return image['src']?.toString() ?? '';
    }

    return category['image']?.toString() ?? '';
  }
}
