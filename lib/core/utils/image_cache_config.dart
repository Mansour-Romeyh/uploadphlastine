import 'package:flutter/material.dart';

/// تعيين حجم الـ image cache: 200 صورة، 100 MB
void configureImageCache() {
  PaintingBinding.instance.imageCache.maximumSize = 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20;
}
