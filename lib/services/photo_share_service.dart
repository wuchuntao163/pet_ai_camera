import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

/// 分享本地照片文件
class PhotoShareService {
  PhotoShareService._();

  static const _jpegMime = 'image/jpeg';

  static String _mimeForPath(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      default:
        return _jpegMime;
    }
  }

  static Future<void> sharePaths(List<String> paths) async {
    final files = <XFile>[];
    for (final rawPath in paths) {
      final filePath = p.normalize(rawPath);
      final file = File(filePath);
      if (!await file.exists()) {
        continue;
      }
      files.add(
        XFile(
          file.path,
          mimeType: _mimeForPath(file.path),
          name: p.basename(file.path),
        ),
      );
    }

    if (files.isEmpty) {
      throw StateError('No shareable photo files found');
    }

    await Share.shareXFiles(
      files,
      fileNameOverrides: files.map((f) => f.name).toList(),
    );

  }
}
