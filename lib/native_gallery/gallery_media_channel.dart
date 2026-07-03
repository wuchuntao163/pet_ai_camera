import 'dart:io';

import 'package:flutter/services.dart';

class GalleryMediaChannel {
  GalleryMediaChannel._();

  static const _channel = MethodChannel('pet_ai_camera/gallery_media');

  /// Android：按 MediaStore id 与 pet_ai 文件名删除系统相册照片。
  static Future<int> deleteAppPhotos({
    required List<String> assetIds,
    required List<String> captureIds,
  }) async {
    if (!Platform.isAndroid) return 0;
    if (assetIds.isEmpty && captureIds.isEmpty) return 0;
    try {
      final count = await _channel.invokeMethod<int>(
        'deleteAppPhotos',
        {
          'assetIds': assetIds,
          'captureIds': captureIds,
        },
      );
      return count ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
