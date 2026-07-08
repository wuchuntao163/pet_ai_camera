import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../native_camera/native_camera_channel.dart';
import 'device_info_service.dart';

/// 相机页后台缓存拍摄坐标，快门后异步写入成片 EXIF（不阻塞左下角缩略图）
class CaptureLocationService {
  CaptureLocationService._();

  static final CaptureLocationService instance = CaptureLocationService._();

  static const _maxCacheAge = Duration(minutes: 10);

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
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 15,
      ),
    ).listen(
      (position) {
        _cached = position;
        _cachedAt = DateTime.now();
      },
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

  /// 写入 GPS 与设备型号到成片 EXIF
  Future<void> stampCaptureMetadata(String path) async {
    await writeGpsToImage(path);
    final device = await DeviceInfoService.exifMakeModel();
    await NativeCameraChannel.writeImageDevice(
      path: path,
      make: device.make,
      model: device.model,
    );
  }

  Future<(double, double)?> _coordinatesForCapture() async {
    final cached = _readCached();
    if (cached != null) return cached;

    if (!await _ensurePermission()) return null;
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && _isValid(last.latitude, last.longitude)) {
        _remember(last);
        return (last.latitude, last.longitude);
      }
    } catch (_) {}

    return null;
  }

  (double, double)? _readCached() {
    final position = _cached;
    if (position == null) return null;
    if (_cachedAt != null &&
        DateTime.now().difference(_cachedAt!) > _maxCacheAge) {
      return null;
    }
    if (!_isValid(position.latitude, position.longitude)) return null;
    return (position.latitude, position.longitude);
  }

  Future<void> _seedFromLastKnown() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && _isValid(last.latitude, last.longitude)) {
        _remember(last);
      }
    } catch (_) {}
  }

  Future<void> _refreshCurrentPosition() async {
    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4),
        ),
      );
      if (_isValid(current.latitude, current.longitude)) {
        _remember(current);
      }
    } catch (_) {}
  }

  void _remember(Position position) {
    _cached = position;
    _cachedAt = DateTime.now();
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  bool _isValid(double lat, double lng) {
    if (!lat.isFinite || !lng.isFinite) return false;
    if (lat == 0 && lng == 0) return false;
    return true;
  }
}
