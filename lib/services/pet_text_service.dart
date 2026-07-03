import 'dart:convert';
import 'dart:io';

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

/// 卡片文案区固定字色（接口未返回文字颜色，默认深灰适配浅色背景）
const Color kPetCopyTextColor = Color(0xFF1F2937);

/// AI 趣味文案生成结果
class PetTextResult {
  final String text;
  final Color backgroundColor;

  const PetTextResult({
    required this.text,
    required this.backgroundColor,
  });

  factory PetTextResult.fromApi(dynamic raw) {
    final data = _coerceResultMap(raw);
    final text = _readNonEmptyString(data, const [
      'text',
      'copywriting',
      'content',
      'copy',
      'desc',
      'description',
      'message',
    ]);
    if (text == null) {
      throw ApiException.business(0, '未生成文案');
    }
    final backgroundColor = _parsePetTextColor(
      _readString(data, const ['color', 'bg_color', 'background', 'bgColor']),
    );
    return PetTextResult(
      text: text,
      backgroundColor: backgroundColor,
    );
  }

  static Map<String, dynamic> _coerceResultMap(dynamic raw) {
    dynamic data = raw;
    if (data == null) {
      throw ApiException.business(0, '返回数据格式错误');
    }
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) {
        throw ApiException.business(0, '返回数据格式错误');
      }
      try {
        data = jsonDecode(trimmed);
      } catch (_) {
        return {'text': trimmed};
      }
    }
    if (data is! Map) {
      throw ApiException.business(0, '返回数据格式错误');
    }

    var map = Map<String, dynamic>.from(data);
    for (var depth = 0; depth < 2; depth++) {
      final nested = map['data'] ?? map['result'] ?? map['payload'];
      if (nested is Map) {
        map = Map<String, dynamic>.from(nested);
        continue;
      }
      if (nested is String && nested.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(nested.trim());
          if (decoded is Map) {
            map = Map<String, dynamic>.from(decoded);
            continue;
          }
        } catch (_) {}
      }
      break;
    }
    return map;
  }

  static String? _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static String? _readNonEmptyString(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    final value = _readString(map, keys);
    if (value == null || value.isEmpty) return null;
    return value;
  }
}

class PetTextService {
  PetTextService._();

  /// [imageUrl] 远程图片 URL；[localPath] 本地路径（优先上传本地图，避免 release 下远程图不可达）
  /// 返回生成结果及实际用于请求的 image URL（便于重新生成复用）
  static Future<({PetTextResult result, String imageUrl})> generate({
    String? imageUrl,
    String? localPath,
  }) async {
    final path = localPath?.trim() ?? '';
    final String url;

    if (path.isNotEmpty && await File(path).exists()) {
      url = await FileUploadService.uploadLocalImage(path);
    } else {
      var remote = imageUrl?.trim() ?? '';
      if (remote.isEmpty) {
        throw ApiException.business(0, '没有可用的照片');
      }
      if (!remote.startsWith('http')) {
        remote = FileUploadService.resolveUrl(remote);
      }
      url = remote;
    }

    final res = await Api.post(
      ApiPaths.generatePetText,
      data: {'image': url},
      receiveTimeout: const Duration(seconds: 60),
    );

    if (!res.isSuccess) {
      throw ApiException.business(
        res.code,
        res.msg.isNotEmpty ? res.msg : '生成失败',
      );
    }

    if (res.data == null) {
      throw ApiException.business(0, '返回数据为空');
    }

    return (
      result: PetTextResult.fromApi(res.data),
      imageUrl: url,
    );
  }
}
