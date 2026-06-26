import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/camera_config.dart';
import '../native_camera/native_camera_channel.dart';

class CapturePhotoResult {
  final String fullPath;

  const CapturePhotoResult({required this.fullPath});
}

/// 原生相机服务（Android CameraX / iOS AVFoundation）
class CameraService {
  bool _initialized = false;
  bool _isBackCamera = true;
  double _baselineOneX = 1.0;
  double _previewAspectRatio = 3 / 4;
  FlashToolbarState? _lastAppliedFlash;

  bool get isInitialized => _initialized;

  bool get isBackCamera => _isBackCamera;

  double get baselineOneX => _baselineOneX;

  double get previewAspectRatio => _previewAspectRatio;

  Future<void> initialize() async {
    final granted = await _ensurePermission();
    if (!granted) throw CameraPermissionException();

    await NativeCameraChannel.dispose();
    final result = await NativeCameraChannel.initialize();
    _applyInitResult(result);
    _initialized = true;
    await setZoomLevel(_baselineOneX);
    debugPrint(
      'Native camera ready: baseline=$_baselineOneX aspect=$_previewAspectRatio '
      'back=$_isBackCamera',
    );
  }

  Future<void> switchCamera() async {
    if (!_initialized) return;
    final result = await NativeCameraChannel.switchCamera();
    _applyInitResult(result);
    _lastAppliedFlash = null;
    await setZoomLevel(_baselineOneX);
  }

  Future<bool> applyToolbarFlash(FlashToolbarState state) async {
    if (!_initialized) return false;
    if (!_isBackCamera && state != FlashToolbarState.off) return false;
    try {
      await NativeCameraChannel.setFlash(state);
      _lastAppliedFlash = state;
      return true;
    } catch (e) {
      debugPrint('applyToolbarFlash failed: $e');
      return false;
    }
  }

  Future<void> syncFlashBeforeCapture(FlashToolbarState state) async {
    if (_lastAppliedFlash == state) return;
    await applyToolbarFlash(state);
  }

  Future<CapturePhotoResult?> takePicture({
    FlashToolbarState? toolbarFlash,
    Map<String, dynamic>? crop,
  }) async {
    if (!_initialized) return null;
    try {
      if (toolbarFlash != null) {
        await syncFlashBeforeCapture(toolbarFlash);
      }
      final sw = Stopwatch()..start();
      final result = await NativeCameraChannel.takePicture(crop: crop);
      sw.stop();
      final nativeMs = result.captureDurationMs;
      debugPrint(
        'NativeCamera: Capture done in ${nativeMs ?? sw.elapsedMilliseconds}ms '
        'direct=${result.directOutput} '
        '(channel=${sw.elapsedMilliseconds}ms)',
      );
      return CapturePhotoResult(fullPath: result.path);
    } catch (e) {
      debugPrint('takePicture failed: $e');
      return null;
    }
  }

  Future<double> ensureBaselineOneX() async => _baselineOneX;

  Future<void> setZoomLevel(double level) async {
    if (!_initialized) return;
    try {
      await NativeCameraChannel.setZoom(level);
    } catch (e) {
      debugPrint('setZoomLevel failed: $e');
    }
  }

  Future<void> setPreviewMode({
    required bool nativeSensorContain,
    double? viewportAspect,
  }) async {
    if (!_initialized) return;
    try {
      final result = await NativeCameraChannel.setPreviewMode(
        contain: nativeSensorContain,
        viewportAspect: viewportAspect,
      );
      _applyInitResult(result);
    } catch (e) {
      debugPrint('setPreviewMode failed: $e');
    }
  }

  Future<void> pause() async {
    if (!_initialized) return;
    await NativeCameraChannel.pause();
  }

  Future<void> resume() async {
    if (!_initialized) return;
    try {
      final result = await NativeCameraChannel.resume();
      _applyInitResult(result);
    } catch (e) {
      debugPrint('resume failed: $e');
    }
  }

  Future<void> dispose() async {
    _initialized = false;
    await NativeCameraChannel.dispose();
  }

  void _applyInitResult(NativeCameraInitResult result) {
    _baselineOneX = result.baselineOneX;
    _previewAspectRatio = result.previewAspectRatio;
    _isBackCamera = result.isBackCamera;
  }

  Future<bool> _ensurePermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted) return true;
    status = await Permission.camera.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }
}

class CameraPermissionException implements Exception {}

class CameraInitException implements Exception {
  final String message;
  CameraInitException(this.message);
}
