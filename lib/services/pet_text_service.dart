import 'package:flutter/material.dart';

import '../api/api.dart';
import '../services/file_upload_service.dart';

/// 将接口返回的 `#RRGGBB` 转为 Flutter [Color]（ARGB 0xAARRGGBB）
Color parseHexColor(String? hex, {Color fallback = const Color(0xFFDDE6ED)}) {
  if (hex == null || hex.isEmpty) return fallback;
  var value = hex.trim().replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return fallback;
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return fallback;
  return Color(parsed);
}

Color _parsePetTextColor(String? hex) => parseHexColor(hex);

/// AI 趣味文案生成结果
class PetTextResult {
  final String text;
  final Color backgroundColor;

  const PetTextResult({
    required this.text,
    required this.backgroundColor,
  });

  factory PetTextResult.fromApi(dynamic data) {
    if (data is! Map) {
      throw ApiException.business(0, '返回数据格式错误');
    }
    final text = data['text']?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw ApiException.business(0, '未生成文案');
    }
    return PetTextResult(
      text: text,
      backgroundColor: _parsePetTextColor(data['color']?.toString()),
    );
  }
}

class PetTextService {
  PetTextService._();

  /// [imageUrl] 远程图片 URL；[localPath] 本地路径（无 URL 时先上传）
  /// 返回生成结果及实际用于请求的 image URL（便于重新生成复用）
  static Future<({PetTextResult result, String imageUrl})> generate({
    String? imageUrl,
    String? localPath,
  }) async {
    var url = imageUrl?.trim() ?? '';
    if (url.isEmpty) {
      final path = localPath?.trim() ?? '';
      if (path.isEmpty) {
        throw ApiException.business(0, '没有可用的照片');
      }
      url = await FileUploadService.uploadLocalImage(path);
    } else if (!url.startsWith('http')) {
      url = FileUploadService.resolveUrl(url);
    }

    final res = await Api.post(
      ApiPaths.generatePetText,
      data: {'image': url},
      receiveTimeout: const Duration(seconds: 60),
    );

    if (!res.isSuccess) {
      throw ApiException.business(res.code, res.msg.isNotEmpty ? res.msg : '生成失败');
    }

    return (
      result: PetTextResult.fromApi(res.data),
      imageUrl: url,
    );
  }
}
