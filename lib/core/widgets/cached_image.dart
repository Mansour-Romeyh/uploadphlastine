import 'package:flutter/material.dart';
import 'package:online_ezzy/core/utils/image_url_utils.dart';

class CachedImage extends StatelessWidget {
  final Object? imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedImageUrl = normalizeImageUrl(imageUrl);

    if (normalizedImageUrl.isEmpty) {
      return errorWidget ??
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.grey[400],
                  size: (width != null && width! < 100) ? 24 : 40,
                ),
                if (width != null && width! >= 100) ...[
                  SizedBox(height: 4),
                  Text(
                    'لا توجد صورة',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          );
    }

    return Image.network(
      normalizedImageUrl,
      fit: fit ?? BoxFit.cover,
      width: width,
      height: height,
      // Enable caching (enabled by default in Flutter)
      cacheWidth: _getCacheSize(width),
      cacheHeight: _getCacheSize(height),
      // Optimize loading
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ??
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFE71D24),
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ??
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.grey[400],
                    size: (width != null && width! < 100) ? 24 : 40,
                  ),
                  if (width != null && width! >= 100) ...[
                    SizedBox(height: 4),
                    Text(
                      'لا توجد صورة',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            );
      },
    );
  }

  int? _getCacheSize(double? size) {
    if (size == null || !size.isFinite || size <= 0) {
      return null;
    }
    // Use 2x for retina displays
    return (size * 2).toInt();
  }
}
