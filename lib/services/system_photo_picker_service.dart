import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/app_photo.dart';

/// 从系统相册读取照片（复制到应用临时目录）
class SystemPhotoPickerService {
  SystemPhotoPickerService._();

  static const _loadLimit = 200;

  static Future<List<AssetEntity>> loadRecentPhotos() async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (paths.isEmpty) return [];

    final album = paths.first;
    final count = await album.assetCountAsync;
    if (count <= 0) return [];

    final end = count > _loadLimit ? _loadLimit : count;
    return album.getAssetListRange(start: 0, end: end);
  }

  static Future<AppPhoto?> appPhotoFromAsset(AssetEntity asset) async {
    final source = await asset.originFile ?? await asset.file;
    if (source == null || !await source.exists()) return null;

    final tempDir = await getTemporaryDirectory();
    final ext = p.extension(source.path);
    final safeExt = ext.isNotEmpty ? ext : '.jpg';
    final destPath = p.join(
      tempDir.path,
      'ai_pick_${DateTime.now().millisecondsSinceEpoch}$safeExt',
    );
    await File(source.path).copy(destPath);

    final capturedAt = asset.createDateTime.millisecondsSinceEpoch;
    return AppPhoto(
      id: 'pick_$capturedAt',
      localPath: destPath,
      galleryAssetId: asset.id,
      createdAtMs: capturedAt,
    );
  }
}
