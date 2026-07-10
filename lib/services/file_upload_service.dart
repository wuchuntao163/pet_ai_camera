import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../api/api.dart';

/// 文件上传：本地图片走 `/api/base/uploadLocalImage`，音频等仍走 `/api/base/upload`
class FileUploadService {
  FileUploadService._();

  static Future<String> uploadFile(
    String localPath, {
    String type = 'image',
    String? path,
  }) async {
    if (type == 'image') {
      return uploadLocalImage(localPath);
    }
    return _uploadViaBase(
      localPath,
      type: type,
      path: path,
    );
  }

  /// 本地图片上传（拍摄成片、缩略图、导出图等）
  static Future<String> uploadLocalImage(String localPath) async {
    return _upload(
      ApiPaths.uploadLocalImage,
      localPath: localPath,
      fields: const {'type': 'image'},
      debugLabel: 'uploadLocalImage',
    );
  }

  /// 上传自定义音效音频，返回可用于 [sound_url] 的完整 URL
  static Future<String> uploadAudio(String localPath) async {
    return _uploadViaBase(
      localPath,
      type: 'audio',
      path: 'sound',
    );
  }

  static Future<String> _uploadViaBase(
    String localPath, {
    required String type,
    String? path,
  }) async {
    final fields = <String, dynamic>{'type': type};
    if (path != null && path.isNotEmpty) {
      fields['path'] = path;
    }
    return _upload(
      ApiPaths.upload,
      localPath: localPath,
      fields: fields,
      debugLabel: type,
    );
  }

  static Future<String> _upload(
    String apiPath, {
    required String localPath,
    required Map<String, dynamic> fields,
    required String debugLabel,
  }) async {
    ApiResponse<dynamic> res;
    try {
      res = await Api.upload(
        apiPath,
        filePath: localPath,
        filename: p.basename(localPath),
        fields: fields,
      );
    } on ApiException catch (e) {
      if (kDebugMode && e.message.isNotEmpty) {
        debugPrint('[FileUploadService] $debugLabel failed: $e');
      }
      rethrow;
    }
    final url = _extractUrl(res.data);
    if (url == null || url.isEmpty) {
      throw ApiException.business(0, '');
    }
    return resolveUrl(url);
  }

  static String resolveUrl(String url) {
    final value = url.trim();
    if (value.isEmpty) return value;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('//')) {
      return 'https:$value';
    }
    if (value.startsWith('/')) {
      return '${ApiConfig.baseUrl}$value';
    }
    return '${ApiConfig.baseUrl}/$value';
  }

  static String? _extractUrl(dynamic data) {
    if (data is Map) {
      return data['url']?.toString() ?? data['image_url']?.toString();
    }
    return data?.toString();
  }
}
