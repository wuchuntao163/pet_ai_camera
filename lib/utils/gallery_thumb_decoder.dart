import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// 从本地照片解码小缩略图，供左下角相册按钮即时显示（避免 Image.file 二次 loading）
Future<Uint8List?> decodeGalleryThumbBytes(String path) {
  return compute(_decodeGalleryThumbIsolate, path);
}

Uint8List? _decodeGalleryThumbIsolate(String path) {
  try {
    final bytes = File(path).readAsBytesSync();
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    final thumb = img.copyResize(
      image,
      width: 96,
      height: 96,
      maintainAspect: true,
    );
    return Uint8List.fromList(img.encodeJpg(thumb, quality: 82));
  } catch (_) {
    return null;
  }
}
