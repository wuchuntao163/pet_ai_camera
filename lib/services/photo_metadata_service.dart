import 'dart:io';

import 'package:exif/exif.dart';
import 'package:geocoding/geocoding.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/app_photo.dart';
import 'device_info_service.dart';

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

  static Future<PhotoMetadata> resolve(AppPhoto photo) async {
    DateTime? capturedAt;
    String? location;
    String? device;

    AssetEntity? asset;
    if (photo.galleryAssetId != null && photo.galleryAssetId!.isNotEmpty) {
      asset = await AssetEntity.fromId(photo.galleryAssetId!);
    }

    if (asset != null) {
      capturedAt = asset.createDateTime;
      await _ensureMediaLocationAccess();
      location = await _locationFromAsset(asset);
    }

    final exifPath = await _resolveExifPath(photo, asset);
    if (exifPath != null) {
      final exif = await _readExif(exifPath);
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
  ) async {
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

    final address = await _reverseGeocode(lat!, lng!);
    if (address != null && address.isNotEmpty) return address;

    return _formatCoordinates(lat, lng);
  }

  static bool _isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (!lat.isFinite || !lng.isFinite) return false;
    if (lat == 0 && lng == 0) return false;
    return true;
  }

  static Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final parts = <String>[
        if (_hasText(place.administrativeArea)) place.administrativeArea!,
        if (_hasText(place.locality)) place.locality!,
        if (_hasText(place.subLocality)) place.subLocality!,
        if (_hasText(place.thoroughfare)) place.thoroughfare!,
      ];
      if (parts.isNotEmpty) {
        return parts.join('');
      }

      if (_hasText(place.street)) return place.street;
      if (_hasText(place.name)) return place.name;
      return null;
    } catch (_) {
      return null;
    }
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

  static String? _formatCoordinates(double? lat, double? lng) {
    if (!_isValidCoordinate(lat, lng)) return null;
    final latAbs = lat!.abs().toStringAsFixed(4);
    final lngAbs = lng!.abs().toStringAsFixed(4);
    final latDir = lat >= 0 ? 'N' : 'S';
    final lngDir = lng >= 0 ? 'E' : 'W';
    return '$latAbs°$latDir $lngAbs°$lngDir';
  }

  static Future<_ExifFields> _readExif(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return const _ExifFields();

      final data = await readExifFromBytes(await file.readAsBytes());
      if (data.isEmpty) return const _ExifFields();

      final make = data['Image Make']?.printable.trim();
      final model = data['Image Model']?.printable.trim();
      final device = _joinDevice(make, model);

      final dateRaw = data['EXIF DateTimeOriginal']?.printable ??
          data['Image DateTime']?.printable;
      final capturedAt = _parseExifDate(dateRaw);

      final lat = _readGpsCoordinate(
        data['GPS GPSLatitude']?.values,
        data['GPS GPSLatitudeRef']?.printable,
      );
      final lng = _readGpsCoordinate(
        data['GPS GPSLongitude']?.values,
        data['GPS GPSLongitudeRef']?.printable,
      );

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
  ) {
    if (values is! IfdRatios || values.ratios.length < 3) return null;
    try {
      final ratios = values.ratios;
      final degrees = ratios[0].toDouble();
      final minutes = ratios[1].toDouble();
      final seconds = ratios[2].toDouble();
      var result = degrees + minutes / 60 + seconds / 3600;
      if (ref == 'S' || ref == 'W') result = -result;
      if (!result.isFinite) return null;
      return result;
    } catch (_) {
      return null;
    }
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
