import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';

/// 相册相关页面 AppBar 右侧 PNG 操作按钮（统一尺寸）
class GalleryAppBarAction extends StatelessWidget {
  final String assetPath;
  final String tooltip;
  final VoidCallback? onPressed;
  final Key? actionKey;
  final double opacity;

  const GalleryAppBarAction({
    super.key,
    this.actionKey,
    required this.assetPath,
    required this.tooltip,
    this.onPressed,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: actionKey,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Opacity(
        opacity: opacity,
        child: Image.asset(
          assetPath,
          width: AppSizes.galleryAppBarActionIcon,
          height: AppSizes.galleryAppBarActionIcon,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
