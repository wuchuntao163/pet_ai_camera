import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../models/camera_config.dart';

class NativeCameraInitResult {
  final double baselineOneX;
  final double minZoom;
  final double maxZoom;
  final double previewAspectRatio;
  final bool isBackCamera;

  const NativeCameraInitResult({
    required this.baselineOneX,
    required this.minZoom,
    required this.maxZoom,
    required this.previewAspectRatio,
    required this.isBackCamera,
  });

  factory NativeCameraInitResult.fromMap(Map<dynamic, dynamic> map) {
    return NativeCameraInitResult(
      baselineOneX: (map['baselineOneX'] as num).toDouble(),
      minZoom: (map['minZoom'] as num).toDouble(),
      maxZoom: (map['maxZoom'] as num).toDouble(),
      previewAspectRatio: (map['previewAspectRatio'] as num).toDouble(),
      isBackCamera: map['isBackCamera'] as bool? ?? true,
    );
  }
}

class NativeCaptureResult {
  final String path;
  final String? thumbnailPath;
  final Uint8List? thumbnailBytes;
  final int? captureDurationMs;
  final bool directOutput;

  const NativeCaptureResult({
    required this.path,
    this.thumbnailPath,
    this.thumbnailBytes,
    this.captureDurationMs,
    this.directOutput = false,
  });

  factory NativeCaptureResult.fromMap(Map<dynamic, dynamic> map) {
    return NativeCaptureResult(
      path: map['path'] as String,
      thumbnailPath: map['thumbnailPath'] as String?,
      thumbnailBytes: _thumbnailBytesFromMap(map['thumbnailBytes']),
      captureDurationMs: (map['captureDurationMs'] as num?)?.toInt(),
      directOutput: map['directOutput'] as bool? ?? false,
    );
  }

  static Uint8List? _thumbnailBytesFromMap(dynamic value) {
    if (value == null) return null;
    if (value is Uint8List) return value;
    if (value is TypedData) {
      return Uint8List.view(
        value.buffer,
        value.offsetInBytes,
        value.lengthInBytes,
      );
    }
    return null;
  }
}

/// 原生相机 MethodChannel（Android CameraX / iOS AVFoundation）
class NativeCameraChannel {
  static const _channel = MethodChannel('com.example.pet_ai_camera/native_camera');

  static Future<NativeCameraInitResult> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('Native camera only supports Android and iOS');
    }
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('initialize');
    if (map == null) throw StateError('Native camera initialize returned null');
    return NativeCameraInitResult.fromMap(map);
  }

  static Future<void> dispose() async {
    try {
      await _channel.invokeMethod<void>('dispose');
    } catch (_) {}
  }

  static Future<NativeCameraInitResult> switchCamera() async {
    final map =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('switchCamera');
    if (map == null) throw StateError('switchCamera returned null');
    return NativeCameraInitResult.fromMap(map);
  }

  static Future<void> setZoom(double zoom) async {
    await _channel.invokeMethod<void>('setZoom', {'zoom': zoom});
  }

  static Future<void> setFlash(FlashToolbarState state) async {
    final mode = switch (state) {
      FlashToolbarState.off => 'off',
      FlashToolbarState.on => 'on',
      FlashToolbarState.auto => 'auto',
    };
    await _channel.invokeMethod<void>('setFlash', {'mode': mode});
  }

  static Future<NativeCaptureResult> takePicture({
    Map<String, dynamic>? crop,
  }) async {
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'takePicture',
      crop != null ? {'crop': crop} : null,
    );
    if (map == null) throw StateError('takePicture returned null');
    return NativeCaptureResult.fromMap(map);
  }

  static Future<NativeCameraInitResult> setPreviewMode({
    required bool contain,
    double? viewportAspect,
  }) async {
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'setPreviewMode',
      {
        'contain': contain,
        'viewportAspect': ?viewportAspect,
      },
    );
    if (map == null) throw StateError('setPreviewMode returned null');
    return NativeCameraInitResult.fromMap(map);
  }

  /// iOS：原生预览层定位（3:4 对齐 Android 取景框）
  static Future<void> setPreviewLayout({
    required bool contain,
    bool fullScreen = true,
    Rect? rect,
  }) async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>(
      'setPreviewLayout',
      {
        'contain': contain,
        'fullScreen': fullScreen,
        if (rect != null) ...{
          'left': rect.left,
          'top': rect.top,
          'width': rect.width,
          'height': rect.height,
        },
      },
    );
  }

  static Future<void> pause() async {
    try {
      await _channel.invokeMethod<void>('pause');
    } catch (_) {}
  }

  static Future<NativeCameraInitResult> resume() async {
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('resume');
    if (map == null) throw StateError('Native camera resume returned null');
    return NativeCameraInitResult.fromMap(map);
  }

  /// 将 GPS 坐标写入 JPEG EXIF（裁切/镜像之后调用）
  static Future<bool> writeImageGps({
    required String path,
    required double latitude,
    required double longitude,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      final ok = await _channel.invokeMethod<bool>(
        'writeImageGps',
        {
          'path': path,
          'latitude': latitude,
          'longitude': longitude,
        },
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 将设备厂商/型号写入 JPEG EXIF
  static Future<bool> writeImageDevice({
    required String path,
    String? make,
    String? model,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      final ok = await _channel.invokeMethod<bool>(
        'writeImageDevice',
        {
          'path': path,
          if (make != null && make.isNotEmpty) 'make': make,
          if (model != null && model.isNotEmpty) 'model': model,
        },
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

}
