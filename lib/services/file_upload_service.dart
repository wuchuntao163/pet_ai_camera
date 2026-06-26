import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../api/api.dart';

/// 文件上传：图片 / 音频等（`/api/base/upload`）
class FileUploadService {
  FileUploadService._();

  static Future<String> uploadLocalImage(String localPath) async {
    return uploadFile(localPath, type: 'image');
  }

  /// 上传自定义音效音频，返回可用于 [sound_url] 的完整 URL
  static Future<String> uploadAudio(String localPath) async {
    return uploadFile(
      localPath,
      type: 'audio',
      path: 'sound',
    );
  }

  static Future<String> uploadFile(
    String localPath, {
    String type = 'image',
    String? path,
  }) async {
    final uploadPath = type == 'image' ? ApiPaths.uploadLocalImage : ApiPaths.upload;
    final fields = <String, dynamic>{'type': type};
    if (path != null && path.isNotEmpty) {
      fields['path'] = path;
    }

    ApiResponse<dynamic> res;
    try {
      if (kDebugMode) {
        debugPrint(
          '[FileUploadService] 开始上传 → $uploadPath\n'
          '  本地文件: $localPath\n'
          '  file 字段: ${p.basename(localPath)}\n'
          '  参数: $fields',
        );
      }
      res = await Api.upload(
        uploadPath,
        filePath: localPath,
        filename: p.basename(localPath),
        fields: fields,
      );
      if (kDebugMode) {
        final pretty = const JsonEncoder.withIndent('  ').convert({
          'code': res.code,
          'msg': res.msg,
          'data': res.data,
        });
        debugPrint('[FileUploadService] 上传返回 ($type):\n$pretty');
        debugPrint('[FileUploadService] 解析 URL: ${_extractUrl(res.data)}');
      }
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('[FileUploadService] upload($type) failed: $e');
      }
      rethrow;
    }
    final url = _extractUrl(res.data);
    if (url == null || url.isEmpty) {
      throw ApiException.business(0, '文件上传失败');
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
