import 'dart:io';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/app_photo.dart';

/// 相册缩略图 / 大图（优先本地缓存，其次网络 URL）
class AppPhotoImage extends StatelessWidget {
  final AppPhoto photo;
  final BoxFit fit;

  const AppPhotoImage({
    super.key,
    required this.photo,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (photo.hasLocalFile) {
      return Image.file(
        File(photo.localPath),
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _remoteOrBroken(),
      );
    }

    return _remoteOrBroken();
  }

  Widget _remoteOrBroken() {
    final url = photo.remoteUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _broken(),
      );
    }

    return _broken();
  }

  Widget _broken() {
    return const ColoredBox(
      color: Color(0xFF27272A),
      child: Center(
        child: Icon(
          Icons.broken_image,
          color: AppColors.textHint,
        ),
      ),
    );
  }
}
