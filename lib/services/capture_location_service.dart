import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../native_camera/native_camera_channel.dart';
import 'device_info_service.dart';

/// 相机页后台缓存拍摄坐标，快门后异步写入成片 EXIF（不阻塞左下角缩略图）
class CaptureLocationService {
  CaptureLocationService._();

  static final CaptureLocationService instance = CaptureLocationService._();

  static const _maxCacheAge = Duration(minutes: 10);
  static const _sessionReuseMaxAge = Duration(minutes: 2);
  static const _peekMaxAge = Duration(seconds: 90);
  static const _lastKnownMaxAge = Duration(minutes: 3);
  static const _maxAcceptableAccuracyMeters = 80.0;
  static const _waitForFixTimeout = Duration(seconds: 3);

  StreamSubscription<Position>? _subscription;
  Position? _cached;
  DateTime? _cachedAt;
  bool _tracking = false;

  bool get isTracking => _tracking;

  /// 相机页可见时启动：先取 lastKnown，再订阅位置更新
  Future<void> start() async {
    if (_tracking) return;
    if (!await _ensurePermission()) return;

    _tracking = true;
    await _seedFromLastKnown();
    unawaited(_refreshCurrentPosition());

    await _subscription?.cancel();
    _subscription = Geolocator.getPositionStream(
      locationSettings: _trackingSettings,
    ).listen(
      (position) => _rememberIfBetter(position),
      onError: (_) {},
    );
  }

  Future<void> stop() async {
    _tracking = false;
    await _subscription?.cancel();
    _subscription = null;
  }

  /// 将缓存坐标写入 JPEG EXIF；无坐标时静默跳过
  Future<bool> writeGpsToImage(String path) async {
    final coords = await _coordinatesForCapture();
    if (coords == null) return false;
    return NativeCameraChannel.writeImageGps(
      path: path,
      latitude: coords.$1,
      longitude: coords.$2,
    );
  }

  /// 写入 GPS、设备型号与拍摄时间到成片 EXIF，并返回本次使用的坐标
  Future<({double lat, double lng})?> stampCaptureMetadata(String path) async {
    final coords = await _coordinatesForCapture(preferFast: true);
    final device = await DeviceInfoService.exifMakeModel();
    final capturedAt = DateTime.now();
    final ok = await NativeCameraChannel.writeCaptureMetadata(
      path: path,
      latitude: coords?.$1,
      longitude: coords?.$2,
      make: device.make,
      model: device.model,
      dateTimeOriginal: _formatExifDateTime(capturedAt),
    );
    if (!ok) {
      debugPrint('CaptureLocationService: writeCaptureMetadata failed for $path');
    }
    if (coords == null) return null;
    return (lat: coords.$1, lng: coords.$2);
  }

  /// 串行写入 EXIF，避免连拍时多张同时落盘导致内存峰值
  Future<({double lat, double lng})?> enqueueStampCaptureMetadata(String path) async {
    final completer = Completer<({double lat, double lng})?>();
    _metadataWriteTail = _metadataWriteTail
        .then((_) => stampCaptureMetadata(path))
        .then((coords) {
      if (!completer.isCompleted) completer.complete(coords);
      return coords;
    }).catchError((Object _, StackTrace __) {
      if (!completer.isCompleted) completer.complete(null);
      return null;
    });
    return completer.future;
  }

  /// 快门前读取已缓存坐标（不触发定位等待；精度或时效不够则返回 null）
  ({double lat, double lng})? peekCachedCoordinates() {
    final cached = _readCached(
      maxAge: _peekMaxAge,
      requireUsable: true,
    );
    if (cached == null) return null;
    return (lat: cached.$1, lng: cached.$2);
  }

  LocationSettings get _trackingSettings {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 2),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 3,
    );
  }

  LocationSettings get _captureFixSettings {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        timeLimit: const Duration(seconds: 6),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      timeLimit: Duration(seconds: 6),
    );
  }

  /// 后台排队写 EXIF，调用方无需 await
  void scheduleStampCaptureMetadata(String path) {
    _metadataWriteTail = _metadataWriteTail
        .then((_) => stampCaptureMetadata(path))
        .catchError((Object _, StackTrace __) => null);
  }

  /// 快门前等待上一张 EXIF 写完（短超时），降低 iOS OOM 风险
  Future<void> awaitMetadataIdle({
    Duration timeout = const Duration(milliseconds: 250),
  }) async {
    try {
      await _metadataWriteTail.timeout(timeout);
    } catch (_) {}
  }

  /// 连拍期间只入队，拍完再 [flushDeferredMetadataWrites] 串行写入
  void deferStampCaptureMetadata(String path) {
    if (_deferredExifPaths.contains(path)) return;
    _deferredExifPaths.add(path);
  }

  /// 连拍结束后依次写入排队中的 EXIF
  Future<void> flushDeferredMetadataWrites() async {
    final paths = List<String>.from(_deferredExifPaths);
    _deferredExifPaths.clear();
    for (final path in paths) {
      await enqueueStampCaptureMetadata(path);
    }
  }

  /// 等待排队中的 EXIF 写入全部完成（进相册前调用）
  Future<void> awaitPendingMetadataWrites() async {
    await _metadataWriteTail;
    if (_deferredExifPaths.isNotEmpty) {
      await flushDeferredMetadataWrites();
    }
  }

  static final List<String> _deferredExifPaths = [];
  static Future<void> _metadataWriteTail = Future.value();

  static String _formatExifDateTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}:${two(value.month)}:${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  /// 快门时复用同一会话内已收敛的坐标，避免连拍每张各取一点
  Future<(double, double)?> _coordinatesForCapture({
    bool preferFast = false,
  }) async {
    final session = _readCached(
      maxAge: _sessionReuseMaxAge,
      requireUsable: true,
    );
    if (session != null) return session;

    if (!preferFast) {
      if (_tracking) {
        final waited = await _waitForAcceptableFix(_waitForFixTimeout);
        if (waited != null) return waited;
      }

      if (await _ensurePermission()) {
        try {
          final current = await Geolocator.getCurrentPosition(
            locationSettings: _captureFixSettings,
          );
          if (_isUsable(current)) {
            _rememberIfBetter(current);
            return (current.latitude, current.longitude);
          }
        } catch (_) {}
      }
    }

    final cached = _readCached(maxAge: _maxCacheAge, requireUsable: true);
    if (cached != null) return cached;

    if (!preferFast && await _ensurePermission()) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && _isValid(last.latitude, last.longitude)) {
          _rememberIfBetter(last);
          return (last.latitude, last.longitude);
        }
      } catch (_) {}
    }

    return null;
  }

  Future<(double, double)?> _waitForAcceptableFix(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final cached = _readCached(
        maxAge: _sessionReuseMaxAge,
        requireUsable: true,
      );
      if (cached != null && _positionUsable(_cached)) {
        return cached;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return _readCached(
      maxAge: _sessionReuseMaxAge,
      requireUsable: true,
    );
  }

  (double, double)? _readCached({
    Duration? maxAge,
    bool requireUsable = false,
  }) {
    final position = _cached;
    if (position == null) return null;
    final limit = maxAge ?? _maxCacheAge;
    if (_cachedAt != null && DateTime.now().difference(_cachedAt!) > limit) {
      return null;
    }
    if (requireUsable && !_positionUsable(position)) return null;
    if (!_isValid(position.latitude, position.longitude)) return null;
    return (position.latitude, position.longitude);
  }

  bool _isFresh(Position position, Duration maxAge) {
    final timestamp = position.timestamp;
    if (timestamp.millisecondsSinceEpoch <= 0) return true;
    return DateTime.now().difference(timestamp) <= maxAge;
  }

  Future<void> _seedFromLastKnown() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null &&
          _isUsable(last) &&
          _isFresh(last, _lastKnownMaxAge)) {
        _rememberIfBetter(last);
      }
    } catch (_) {}
  }

  Future<void> _refreshCurrentPosition() async {
    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: _captureFixSettings,
      );
      if (_isUsable(current)) {
        _rememberIfBetter(current);
      }
    } catch (_) {}
  }

  void _rememberIfBetter(Position position) {
    if (!_isValid(position.latitude, position.longitude)) return;

    final previous = _cached;
    if (previous == null) {
      _cached = position;
      _cachedAt = DateTime.now();
      return;
    }

    if (_accuracyMeters(position) < _accuracyMeters(previous)) {
      _cached = position;
      _cachedAt = DateTime.now();
    }
  }

  bool _positionUsable(Position? position) {
    if (position == null) return false;
    if (!_isValid(position.latitude, position.longitude)) return false;
    final accuracy = _accuracyMeters(position);
    return accuracy <= _maxAcceptableAccuracyMeters;
  }

  bool _isUsable(Position position) {
    if (!_isValid(position.latitude, position.longitude)) return false;
    final accuracy = _accuracyMeters(position);
    if (accuracy < 0) return true;
    return accuracy <= _maxAcceptableAccuracyMeters * 2;
  }

  double _accuracyMeters(Position position) {
    final accuracy = position.accuracy;
    if (!accuracy.isFinite || accuracy < 0) return double.infinity;
    return accuracy;
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return false;
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  bool _isValid(double lat, double lng) {
    if (!lat.isFinite || !lng.isFinite) return false;
    if (lat == 0 && lng == 0) return false;
    return true;
  }
}
