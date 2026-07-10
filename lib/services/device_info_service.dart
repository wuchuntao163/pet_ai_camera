import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../utils/ios_device_marketing_name.dart';

/// 本机设备型号（用于元数据展示与写入 EXIF 的兜底）
class DeviceInfoService {
  DeviceInfoService._();

  static final DeviceInfoPlugin _plugin = DeviceInfoPlugin();
  static String? _cachedDisplayName;
  static String? _cachedMake;
  static String? _cachedModel;

  static Future<String> displayName() async {
    if (_cachedDisplayName != null) return _cachedDisplayName!;
    final fields = await _loadFields();
    _cachedDisplayName = fields.displayName;
    return _cachedDisplayName!;
  }

  static Future<({String? make, String? model})> exifMakeModel() async {
    final fields = await _loadFields();
    return (make: fields.make, model: fields.model);
  }

  static Future<_DeviceFields> _loadFields() async {
    if (_cachedDisplayName != null) {
      return _DeviceFields(
        displayName: _cachedDisplayName!,
        make: _cachedMake,
        model: _cachedModel,
      );
    }

    try {
      if (Platform.isAndroid) {
        final info = await _plugin.androidInfo;
        final make = _capitalizeWords(info.manufacturer.trim());
        final model = info.model.trim();
        final display = _joinParts([make, model]) ?? model;
        _cachedMake = make.isNotEmpty ? make : null;
        _cachedModel = model.isNotEmpty ? model : null;
        _cachedDisplayName =
            display.isNotEmpty ? display : 'Android';
        return _DeviceFields(
          displayName: _cachedDisplayName!,
          make: _cachedMake,
          model: _cachedModel,
        );
      }

      if (Platform.isIOS) {
        final info = await _plugin.iosInfo;
        const make = 'Apple';
        final machine = info.utsname.machine.trim();
        final model = iosMarketingName(machine) ??
            (info.model.trim().isNotEmpty ? info.model.trim() : 'iPhone');
        _cachedMake = make;
        _cachedModel = model;
        _cachedDisplayName = _joinParts([make, model]) ?? model;
        return _DeviceFields(
          displayName: _cachedDisplayName!,
          make: _cachedMake,
          model: _cachedModel,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DeviceInfoService: $e');
      }
    }

    _cachedDisplayName = Platform.isIOS ? 'iPhone' : 'Android';
    return _DeviceFields(displayName: _cachedDisplayName!);
  }

  static String? _joinParts(List<String?> parts) {
    final cleaned = parts
        .map((part) => part?.trim())
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) return null;
    return cleaned.join(' ');
  }

  static String _capitalizeWords(String value) {
    if (value.isEmpty) return value;
    return value
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          if (word.length == 1) return word.toUpperCase();
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }
}

class _DeviceFields {
  final String displayName;
  final String? make;
  final String? model;

  const _DeviceFields({
    required this.displayName,
    this.make,
    this.model,
  });
}
