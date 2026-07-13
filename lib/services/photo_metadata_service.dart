import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:geocoding/geocoding.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/app_photo.dart';
import '../utils/china_coordinate.dart';
import 'device_info_service.dart';
import 'photo_gallery_service.dart';

/// 照片元数据（拍摄地点、时间、设备）
class PhotoMetadata {
  final String location;
  final String capturedAt;
  final String device;

  const PhotoMetadata({
    required this.location,
    required this.capturedAt,
    required this.device,
  });

  static const unknownLocation = '暂无位置信息';
  static const unknownDevice = '暂无设备信息';
}

/// 从相册资产或图片 EXIF 解析元数据
class PhotoMetadataService {
  PhotoMetadataService._();

  static const _exifHeaderMaxBytes = 512 * 1024;

  static Future<PhotoMetadata> resolve(
    AppPhoto photo, {
    PhotoGalleryService? galleryService,
  }) async {
    DateTime? capturedAt;
    String? location;
    String? device;

    if (galleryService != null) {
      final stored = await galleryService.captureCoordinatesFor(photo);
      if (stored != null) {
        location = await _locationFromCoordinates(stored.lat, stored.lng);
      }
    } else if (photo.hasCaptureCoordinates) {
      location = await _locationFromCoordinates(
        photo.captureLatitude,
        photo.captureLongitude,
      );
    }

    AssetEntity? asset;
    if (photo.galleryAssetId != null && photo.galleryAssetId!.isNotEmpty) {
      asset = await AssetEntity.fromId(photo.galleryAssetId!);
    }

    if (asset != null) {
      capturedAt = asset.createDateTime;
      if (location == null) {
        await _ensureMediaLocationAccess();
        location = await _locationFromAsset(asset);
      }
    }

    final exifPath = await _resolveExifPath(photo, asset, galleryService);
    if (exifPath != null) {
      final exif = await _readExif(
        exifPath,
        needGps: location == null,
      );
      device = exif.device;
      capturedAt ??= exif.capturedAt;
      location ??= await _locationFromCoordinates(exif.lat, exif.lng);
    }

    capturedAt ??= DateTime.fromMillisecondsSinceEpoch(photo.createdAtMs);
    return PhotoMetadata(
      location: location ?? PhotoMetadata.unknownLocation,
      capturedAt: _formatDateTime(capturedAt),
      device: device ?? await DeviceInfoService.displayName(),
    );
  }

  static Future<String?> _resolveExifPath(
    AppPhoto photo,
    AssetEntity? asset,
    PhotoGalleryService? galleryService,
  ) async {
    if (galleryService != null) {
      final preferred = await galleryService.metadataExifPathFor(photo);
      if (preferred != null) return preferred;
    }
    if (photo.hasLocalFile) return photo.localPath;
    if (asset == null) return null;
    final origin = await asset.originFile;
    return origin?.path;
  }

  static Future<void> _ensureMediaLocationAccess() async {
    await PhotoManager.requestPermissionExtend(
      requestOption: PermissionRequestOption(
        androidPermission: const AndroidPermission(
          type: RequestType.image,
          mediaLocation: true,
        ),
        iosAccessLevel: IosAccessLevel.readWrite,
      ),
    );
  }

  static Future<String?> _locationFromAsset(AssetEntity asset) async {
    try {
      final latLng = await asset.latlngAsync();
      return _locationFromCoordinates(latLng.latitude, latLng.longitude);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _locationFromCoordinates(
    double? lat,
    double? lng,
  ) async {
    if (!_isValidCoordinate(lat, lng)) return null;
    return _reverseGeocode(lat!, lng!);
  }

  static bool _isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (!lat.isFinite || !lng.isFinite) return false;
    if (lat == 0 && lng == 0) return false;
    return true;
  }

  static Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      if (!ChinaCoordinate.isInChina(lat, lng)) {
        return (await _placemarkCandidate(lat, lng))?.address;
      }

      final gcj = ChinaCoordinate.forGeocoding(lat, lng);

      // Android 部分机型定位已是 GCJ-02，再转换会二次偏移；双候选取更细地址
      if (Platform.isAndroid) {
        final candidates = await Future.wait([
          _placemarkCandidate(lat, lng),
          _placemarkCandidate(gcj.lat, gcj.lng),
        ]);
        return _bestAddress(candidates);
      }

      final fromAdjusted = await _placemarkCandidate(gcj.lat, gcj.lng);
      if (fromAdjusted != null) return fromAdjusted.address;
      return (await _placemarkCandidate(lat, lng))?.address;
    } catch (_) {
      return null;
    }
  }

  static String? _bestAddress(List<_AddressCandidate?> candidates) {
    _AddressCandidate? best;
    for (final candidate in candidates) {
      if (candidate == null) continue;
      if (best == null || candidate.score > best.score) {
        best = candidate;
      }
    }
    return best?.address;
  }

  static Future<_AddressCandidate?> _placemarkCandidate(
    double lat,
    double lng,
  ) async {
    final placemarks = await placemarkFromCoordinates(lat, lng);
    if (placemarks.isEmpty) return null;

    final place = placemarks.first;
    final address = _formatPlacemark(place);
    if (address == null || address.isEmpty) return null;
    return _AddressCandidate(address, _scorePlacemark(place, address));
  }

  static String? _formatPlacemark(Placemark place) {
    final parts = <String>[];

    void addPart(String? value) {
      if (!_hasText(value)) return;
      final text = _sanitizeAddressPart(value!.trim());
      if (text == null || text.isEmpty) return;
      if (_looksLikeCoordinateText(text)) return;
      parts.add(text);
    }

    addPart(place.administrativeArea);
    addPart(place.locality);
    addPart(place.subAdministrativeArea);
    addPart(place.subLocality);
    addPart(place.thoroughfare);

    if (parts.isEmpty) {
      addPart(place.name);
    }

    final joined = _joinAddressParts(parts);
    if (joined.isEmpty) return null;
    return _truncateAfterRoad(joined);
  }

  /// 只保留到路名（含「路」「大道」），后面的门牌、楼栋等一律去掉。
  static String _truncateAfterRoad(String address) {
    final match = RegExp(r'路|大道').firstMatch(address);
    if (match == null) return address;
    return address.substring(0, match.end);
  }

  /// 拼接时去掉 Android 常见的重叠字段，如「罗湖区」+「罗湖区」、「蜜园路」+「蜜园路」。
  static String _joinAddressParts(List<String> parts) {
    var result = '';
    for (final part in parts) {
      if (part.isEmpty) continue;
      if (result.isEmpty) {
        result = part;
        continue;
      }
      if (result.contains(part)) continue;
      if (part.contains(result)) {
        result = part;
        continue;
      }
      if (result.endsWith(part)) continue;
      result += part;
    }
    return result;
  }

  /// 过滤行政街道、巷弄及门牌号，保留省市区与路名等常规信息。
  static String? _sanitizeAddressPart(String text) {
    if (text.isEmpty) return null;

    // 不显示行政「xx街道」
    if (RegExp(r'街道$').hasMatch(text)) return null;

    // 不显示以「巷」结尾的巷弄名
    if (RegExp(r'巷$').hasMatch(text)) return null;

    // 去掉门牌号，如「蜜园路88号」→「蜜园路」
    var cleaned = text.replaceAll(RegExp(r'\d+号'), '');
    cleaned = cleaned.replaceAll(RegExp(r'号\d*'), '');
    cleaned = cleaned.trim();
    if (cleaned.isEmpty) return null;

    return cleaned;
  }

  static int _scorePlacemark(Placemark place, String address) {
    var score = 0;
    if (_hasText(place.thoroughfare)) score += 25;
    if (_hasText(place.subLocality) &&
        !RegExp(r'街道$').hasMatch(place.subLocality!.trim())) {
      score += 8;
    }
    if (RegExp(r'[路大道]').hasMatch(address)) score += 10;
    if (RegExp(r'街道$').hasMatch(address)) score -= 12;
    return score;
  }

  static bool _looksLikeCoordinateText(String value) {
    final text = value.trim();
    if (text.isEmpty) return true;
    if (text.contains('纬度') || text.contains('经度')) return true;
    if (RegExp(r'^[+-]?\d+(?:\.\d+)?$').hasMatch(text)) return true;
    if (RegExp(r'^\d+(?:\.\d+)?°[NSWE]$').hasMatch(text)) return true;
    return false;
  }

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;

  static String _formatDateTime(DateTime value) {
    final month = value.month;
    final day = value.day;
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}年$month月$day日 $hour:$minute';
  }

  static Future<_ExifFields> _readExif(
    String path, {
    required bool needGps,
  }) async {
    try {
      final file = File(path);
      if (!await file.exists()) return const _ExifFields();

      final bytes = await _readExifHeaderBytes(file);
      final data = await readExifFromBytes(bytes);
      if (data.isEmpty) return const _ExifFields();

      final make = data['Image Make']?.printable.trim();
      final model = data['Image Model']?.printable.trim();
      final device = _joinDevice(make, model);

      final dateRaw = data['EXIF DateTimeOriginal']?.printable ??
          data['Image DateTime']?.printable;
      final capturedAt = _parseExifDate(dateRaw);

      double? lat;
      double? lng;
      if (needGps) {
        lat = _readGpsCoordinate(
          data['GPS GPSLatitude']?.values,
          data['GPS GPSLatitudeRef']?.printable,
          data['GPS GPSLatitude']?.printable,
        );
        lng = _readGpsCoordinate(
          data['GPS GPSLongitude']?.values,
          data['GPS GPSLongitudeRef']?.printable,
          data['GPS GPSLongitude']?.printable,
        );
        if (!_isValidCoordinate(lat, lng)) {
          lat = null;
          lng = null;
        }
      }

      return _ExifFields(
        capturedAt: capturedAt,
        lat: lat,
        lng: lng,
        device: device,
      );
    } catch (_) {
      return const _ExifFields();
    }
  }

  static Future<Uint8List> _readExifHeaderBytes(File file) async {
    final raf = await file.open();
    try {
      final total = await raf.length();
      final length = math.min(total, _exifHeaderMaxBytes);
      return await raf.read(length);
    } finally {
      await raf.close();
    }
  }

  static String? _joinDevice(String? make, String? model) {
    final parts = <String>[
      if (make != null && make.isNotEmpty) make,
      if (model != null && model.isNotEmpty) model,
    ];
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  static DateTime? _parseExifDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.trim().split(' ');
    if (parts.isEmpty) return null;
    final dateParts = parts[0].split(':');
    if (dateParts.length != 3) return null;
    final timeParts =
        parts.length > 1 ? parts[1].split(':') : const ['0', '0', '0'];
    return DateTime(
      int.tryParse(dateParts[0]) ?? 0,
      int.tryParse(dateParts[1]) ?? 1,
      int.tryParse(dateParts[2]) ?? 1,
      int.tryParse(timeParts.elementAtOrNull(0) ?? '0') ?? 0,
      int.tryParse(timeParts.elementAtOrNull(1) ?? '0') ?? 0,
      int.tryParse(timeParts.elementAtOrNull(2) ?? '0') ?? 0,
    );
  }

  static double? _readGpsCoordinate(
    IfdValues? values,
    String? ref,
    String? printable,
  ) {
    final fromValues = _gpsValuesToFloat(values);
    if (fromValues != null) {
      return _applyGpsRef(fromValues, ref);
    }
    return _parseGpsPrintable(printable, ref);
  }

  static double? _gpsValuesToFloat(IfdValues? values) {
    if (values is! IfdRatios || values.ratios.isEmpty) return null;
    try {
      var result = 0.0;
      var unit = 1.0;
      for (final ratio in values.ratios) {
        result += ratio.toDouble() * unit;
        unit /= 60.0;
      }
      if (!result.isFinite) return null;
      return result;
    } catch (_) {
      return null;
    }
  }

  static double? _applyGpsRef(double value, String? ref) {
    var result = value;
    if (ref == 'S' || ref == 'W') result = -result;
    if (!result.isFinite) return null;
    return result;
  }

  static double? _parseGpsPrintable(String? printable, String? ref) {
    if (printable == null || printable.isEmpty) return null;
    final matches = RegExp(r'(-?\d+(?:\.\d+)?)').allMatches(printable);
    final numbers = matches
        .map((match) => double.tryParse(match.group(1)!))
        .whereType<double>()
        .toList();
    if (numbers.isEmpty) return null;

    double result;
    if (numbers.length >= 3) {
      result = numbers[0] + numbers[1] / 60 + numbers[2] / 3600;
    } else if (numbers.length == 2) {
      result = numbers[0] + numbers[1] / 60;
    } else {
      result = numbers[0];
    }
    return _applyGpsRef(result, ref);
  }
}

class _ExifFields {
  final DateTime? capturedAt;
  final double? lat;
  final double? lng;
  final String? device;

  const _ExifFields({
    this.capturedAt,
    this.lat,
    this.lng,
    this.device,
  });
}

class _AddressCandidate {
  final String address;
  final int score;

  const _AddressCandidate(this.address, this.score);
}
