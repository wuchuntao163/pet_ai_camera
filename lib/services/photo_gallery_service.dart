import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import 'capture_location_service.dart';
import '../data/camera_record_store.dart';
import '../models/app_photo.dart';
import '../native_gallery/gallery_media_channel.dart';

/// 管理本应用拍摄的照片：本地存储 + 系统相册同步
class PhotoGalleryService {
  static const _indexFileName = 'photos_index.json';
  static const _cloudGalleryIndexFileName = 'cloud_gallery_index.json';
  static const _galleryAssetMapFileName = 'gallery_asset_map.json';
  static const _cloudCacheFolder = 'cloud_cache';
  static const _albumFolder = 'Pictures/PetAiCamera';

  final List<AppPhoto> _photos = [];
  List<AppPhoto> _cloudGalleryPhotos = [];
  final Map<int, String> _galleryAssetByRecordId = {};
  final Map<int, String> _captureIdByRecordId = {};
  final Set<int> _albumUploadRecordIds = {};
  bool _loaded = false;
  int _saveSeq = 0;
  Directory? _cachedPhotosDir;
  Directory? _cloudCacheDir;
  ({String id, String path})? _readyCaptureSlot;
  Future<void> _uploadTail = Future.value();
  Future<void> _gallerySyncTail = Future.value();
  Future<void> _captureRegisterTail = Future.value();
  int _pendingCaptureSaveCount = 0;

  List<AppPhoto> get photos => List.unmodifiable(_photos);

  /// 相册页展示：仅云端拍摄记录
  List<AppPhoto> get cloudGalleryPhotos =>
      List.unmodifiable(_cloudGalleryPhotos);

  AppPhoto? get latestPhoto {
    if (_cloudGalleryPhotos.isNotEmpty) return _cloudGalleryPhotos.first;
    return _photos.isEmpty ? null : _photos.first;
  }

  Future<void> init() async {
    if (_loaded) return;
    await _loadIndex();
    await _loadCloudGalleryIndex();
    await _loadGalleryAssetMap();
    _rebuildGalleryAssetMapFromPhotos();
    await _photosDirectory();
    await _cloudCacheDirectory();
    _loaded = true;
    unawaited(warmCaptureSlot());
  }

  /// 相机左下角缩略图：与相册页 [cloudGalleryPhotos] 同源（不含仅本地未入库成片）
  Future<AppPhoto?> latestGalleryThumbPhoto() async {
    await init();
    final merged = await _mergeLocalCapturesIntoCloudGallery(
      _cloudGalleryPhotos,
      includePendingLocals: false,
    );
    for (final photo in merged) {
      final resolved = await _resolveDisplayPhoto(photo);
      if (resolved != null) return resolved;
    }
    return null;
  }

  /// 相机左下角缩略图：优先本地/缓存，其次云端 URL
  Future<AppPhoto?> latestDisplayPhoto() async {
    await init();

    for (final photo in _cloudGalleryPhotos) {
      final resolved = await _resolveDisplayPhoto(photo);
      if (resolved != null) return resolved;
    }
    for (final photo in _photos) {
      final resolved = await _resolveDisplayPhoto(photo);
      if (resolved != null) return resolved;
    }
    return _newestLocalCaptureFromDisk();
  }

  Future<AppPhoto?> _resolveDisplayPhoto(AppPhoto photo) async {
    if (photo.hasLocalFile) {
      if (await File(photo.localPath).exists()) return photo;
    }
    final recordId = photo.serverRecordId;
    if (recordId != null && recordId > 0) {
      final cachePath = await _cachePathForRecord(recordId);
      if (await File(cachePath).exists()) {
        return photo.copyWith(localPath: cachePath);
      }
    }
    final url = photo.remoteUrl;
    if (url != null && url.isNotEmpty) return photo;
    return null;
  }

  Future<AppPhoto?> _newestLocalCaptureFromDisk() async {
    try {
      final dir = await _photosDirectory();
      File? newest;
      var newestMs = 0;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.startsWith('pet_') || !name.endsWith('.jpg')) continue;
        final modified = (await entity.stat()).modified.millisecondsSinceEpoch;
        if (modified > newestMs) {
          newestMs = modified;
          newest = entity;
        }
      }
      if (newest == null) return null;
      final baseName = p.basenameWithoutExtension(newest.path);
      final id = baseName.startsWith('pet_')
          ? baseName.substring('pet_'.length)
          : baseName;
      return AppPhoto(
        id: id,
        localPath: newest.path,
        createdAtMs: newestMs,
      );
    } catch (_) {
      return null;
    }
  }

  /// 预热线程：快门时直接取路径，避免 await 目录/ID
  Future<void> warmCaptureSlot() async {
    if (_readyCaptureSlot != null) return;
    await init();
    final photosDir = await _photosDirectory();
    final id = _nextPhotoId();
    final path = p.join(photosDir.path, 'pet_$id.jpg');
    _readyCaptureSlot = (id: id, path: path);
  }

  /// 获取预分配路径；若无缓存则同步申请
  Future<({String id, String path})> acquireCaptureSlot() async {
    final cached = _readyCaptureSlot;
    if (cached != null) {
      _readyCaptureSlot = null;
      unawaited(warmCaptureSlot());
      return cached;
    }
    final slot = await reserveCapturePath();
    unawaited(warmCaptureSlot());
    return slot;
  }

  Future<bool> ensurePermission() async {
    if (Platform.isAndroid) {
      await _requestAndroidGalleryPermission();
    }

    final state = await PhotoManager.requestPermissionExtend(
      requestOption: PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: false,
        ),
        iosAccessLevel: IosAccessLevel.readWrite,
      ),
    );
    return state.isAuth || state.hasAccess;
  }

  Future<void> _requestAndroidGalleryPermission() async {
    var photos = await Permission.photos.status;
    if (!photos.isGranted && !photos.isLimited) {
      photos = await Permission.photos.request();
    }
    if (photos.isGranted || photos.isLimited) return;

    var storage = await Permission.storage.status;
    if (!storage.isGranted) {
      await Permission.storage.request();
    }
  }

  /// 预分配成片路径，供原生相机直接写入（省掉 rename）
  Future<({String id, String path})> reserveCapturePath() async {
    await init();
    final photosDir = await _photosDirectory();
    final id = _nextPhotoId();
    final path = p.join(photosDir.path, 'pet_$id.jpg');
    return (id: id, path: path);
  }

  /// 同步取预热线程路径（快门关键路径零 await）
  ({String id, String path})? takeReadyCaptureSlot() {
    final cached = _readyCaptureSlot;
    if (cached == null) return null;
    _readyCaptureSlot = null;
    unawaited(warmCaptureSlot());
    return cached;
  }

  /// 连拍结束后，把尚未写入系统相册的本地成片依次同步（走串行队列）
  Future<void> flushPendingSystemGallerySync() async {
    await init();
    final pendingIds = _photos
        .where((photo) => photo.hasLocalFile && photo.galleryAssetId == null)
        .map((photo) => photo.id)
        .toList();
    for (final id in pendingIds) {
      await syncToSystemGallery(id);
    }
  }

  /// 原生已写入 [localPath] 后登记索引（无文件拷贝）
  Future<bool> registerCapture({
    required String id,
    required String localPath,
    int? soundEffectId,
    double? captureLatitude,
    double? captureLongitude,
    bool upload = true,
    bool syncToGallery = true,
  }) {
    final completer = Completer<bool>();
    _captureRegisterTail = _captureRegisterTail
        .then((_) => _registerCaptureImpl(
              id: id,
              localPath: localPath,
              soundEffectId: soundEffectId,
              captureLatitude: captureLatitude,
              captureLongitude: captureLongitude,
              upload: upload,
              syncToGallery: syncToGallery,
            ))
        .then((ok) {
      if (!completer.isCompleted) completer.complete(ok);
      return ok;
    }).catchError((Object e, StackTrace stack) {
      debugPrint('PhotoGalleryService: registerCapture error: $e');
      if (!completer.isCompleted) completer.complete(false);
      return false;
    });
    return completer.future;
  }

  Future<bool> _registerCaptureImpl({
    required String id,
    required String localPath,
    int? soundEffectId,
    double? captureLatitude,
    double? captureLongitude,
    bool upload = true,
    bool syncToGallery = true,
  }) async {
    await init();
    if (!await File(localPath).exists()) return false;

    final existing = _photos.indexWhere((photo) => photo.id == id);
    if (existing >= 0) {
      _photos[existing] = _photos[existing].copyWith(localPath: localPath);
    } else {
      final photo = AppPhoto(
        id: id,
        localPath: localPath,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        captureLatitude: captureLatitude,
        captureLongitude: captureLongitude,
      );
      _photos.insert(0, photo);
    }
    unawaited(_persistIndex());
    if (upload) {
      final ok = await uploadRecordForPhoto(id, soundEffectId: soundEffectId);
      if (syncToGallery) {
        unawaited(syncToSystemGallery(id));
      }
      return ok;
    }
    if (syncToGallery) {
      await syncToSystemGallery(id);
    }
    return true;
  }

  /// 等待进行中的成片登记、EXIF、上传与系统相册同步（相册拉取前调用）
  Future<void> waitForPendingUploads() async {
    await _waitForCaptureSaveIdle();
    await _captureRegisterTail;
    await CaptureLocationService.instance.awaitPendingMetadataWrites();
    await _retryPendingUploads();
    await _uploadTail;
    await _gallerySyncTail;
  }

  /// 单张拍摄后处理前：等登记与上传完成，避免与 EXIF 写同一文件并发
  Future<void> awaitShutterUploadIdle() async {
    await _waitForCaptureSaveIdle();
    await _captureRegisterTail;
    await _uploadTail;
  }

  /// 跟踪后台成片登记，避免进相册时漏等尚未入队的上传
  Future<T> trackCaptureSave<T>(Future<T> Function() work) async {
    _pendingCaptureSaveCount++;
    try {
      return await work();
    } finally {
      _pendingCaptureSaveCount--;
    }
  }

  Future<void> _waitForCaptureSaveIdle() async {
    while (_pendingCaptureSaveCount > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  }

  Future<void> _retryPendingUploads() async {
    await init();
    final pendingIds = _photos
        .where((photo) => photo.recordId == null && photo.hasLocalFile)
        .map((photo) => photo.id)
        .toList();
    for (final id in pendingIds) {
      await uploadRecordForPhoto(id);
    }
  }

  Future<void> _upsertCloudGalleryPhoto(AppPhoto uploaded) async {
    final recordId = uploaded.recordId;
    final remoteUrl = uploaded.remoteUrl;
    if (recordId == null || recordId <= 0) return;
    if (remoteUrl == null || remoteUrl.isEmpty) return;

    final cloudPhoto = AppPhoto(
      id: 'record_$recordId',
      localPath: '',
      recordId: recordId,
      remoteUrl: remoteUrl,
      createdAtMs: uploaded.createdAtMs,
      captureLatitude: uploaded.captureLatitude,
      captureLongitude: uploaded.captureLongitude,
    );
    // 仅预缓存成片；相册列表以接口为准，不在此处写入展示列表
    await _materializeCloudPhotoCache(
      cloudPhoto,
      localCapture: uploaded,
    );
  }

  /// 先保存到应用目录；[moveFile] 为 true 时移动文件（裁切后更快）
  Future<AppPhoto?> saveCaptureLocal(
    String tempPath, {
    bool moveFile = false,
    int? soundEffectId,
  }) async {
    await init();

    final tempFile = File(tempPath);
    if (!await tempFile.exists()) return null;

    final photosDir = await _photosDirectory();
    final id = _nextPhotoId();
    final fileName = 'pet_$id.jpg';
    final localPath = p.join(photosDir.path, fileName);

    if (moveFile) {
      try {
        await tempFile.rename(localPath);
      } catch (_) {
        await tempFile.copy(localPath);
        await tempFile.delete();
      }
    } else {
      await tempFile.copy(localPath);
    }

    final photo = AppPhoto(
      id: id,
      localPath: localPath,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _photos.insert(0, photo);
    unawaited(_persistIndex());
    unawaited(uploadRecordForPhoto(id, soundEffectId: soundEffectId));
    return photo;
  }

  /// 从系统相册导入：落盘并 saveCameraRecord；不写入系统相册
  Future<({bool ok, String msg})> importFromSystemAlbum(String tempPath) async {
    await init();
    final tempFile = File(tempPath);
    if (!await tempFile.exists()) {
      return (ok: false, msg: '保存照片失败');
    }

    final slot = await acquireCaptureSlot();
    try {
      try {
        await tempFile.rename(slot.path);
      } catch (_) {
        await tempFile.copy(slot.path);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } catch (_) {
      return (ok: false, msg: '保存照片失败');
    }

    final uploaded = await registerCapture(
      id: slot.id,
      localPath: slot.path,
      syncToGallery: false,
    );
    if (!uploaded) {
      return (ok: false, msg: '保存记录失败，请重试');
    }

    final index = _photos.indexWhere((item) => item.id == slot.id);
    if (index < 0 || _photos[index].recordId == null) {
      return (ok: false, msg: '保存记录失败，请重试');
    }

    final recordId = _photos[index].recordId!;
    _photos[index] = _photos[index].copyWith(fromAlbumUpload: true);
    _rememberAlbumUpload(recordId);
    await _persistIndex();

    await refreshFromServer();
    return (ok: true, msg: '');
  }

  /// 上传本地照片并调用 saveCameraRecord；成功则写入云端相册列表
  Future<bool> uploadRecordForPhoto(
    String photoId, {
    int? soundEffectId,
  }) async {
    final completer = Completer<bool>();
    _uploadTail = _uploadTail
        .then((_) => _uploadRecordForPhotoImpl(
              photoId,
              soundEffectId: soundEffectId,
            ))
        .then((ok) {
      if (!completer.isCompleted) completer.complete(ok);
      return ok;
    }).catchError((Object e, StackTrace stack) {
      debugPrint('PhotoGalleryService: uploadRecordForPhoto error: $e');
      if (!completer.isCompleted) completer.complete(false);
      return false;
    });
    return completer.future;
  }

  Future<bool> _uploadRecordForPhotoImpl(
    String photoId, {
    int? soundEffectId,
  }) async {
    await init();
    final index = _photos.indexWhere((photo) => photo.id == photoId);
    if (index < 0) return false;

    final photo = _photos[index];
    if (photo.recordId != null) return true;
    if (!photo.hasLocalFile) return false;

    final result = await CameraRecordStore.instance.saveRecord(
      localFilePath: photo.localPath,
      recordType: 1,
      soundEffectId: soundEffectId,
    );
    if (!result.ok || result.recordId == null) {
      if (result.msg.isNotEmpty) {
        debugPrint(
          'PhotoGalleryService: uploadRecordForPhoto failed: ${result.msg}',
        );
      }
      return false;
    }

    final updated = photo.copyWith(
      recordId: result.recordId,
      remoteUrl: result.fileUrl,
    );
    _photos[index] = updated;
    if (updated.galleryAssetId != null) {
      _rememberGalleryAsset(result.recordId!, updated.galleryAssetId!);
    }
    _rememberCaptureId(result.recordId!, photoId);
    await _persistIndex();
    unawaited(_upsertCloudGalleryPhoto(updated));
    return true;
  }

  /// 从接口拉取拍摄记录（接口为唯一数据源），并缓存图片到本地
  Future<void> refreshFromServer({int recordType = 1}) async {
    await init();

    final previousByRecordId = <int, AppPhoto>{};
    for (final photo in _cloudGalleryPhotos) {
      final recordId = photo.serverRecordId;
      if (recordId != null && recordId > 0) {
        previousByRecordId[recordId] = photo;
      }
    }

    try {
      await CameraRecordStore.instance.fetchList(recordType: recordType);
    } catch (_) {
      return;
    }

    final records = CameraRecordStore.instance.records;
    final fromApi = <AppPhoto>[];
    final apiRecordIds = <int>{};

    for (final record in records) {
      if (_asInt(record['is_show']) == 0) continue;

      final recordId = CameraRecordStore.listRecordId(record);
      if (recordId <= 0) continue;

      final fileUrl = record['file_url']?.toString() ?? '';
      if (fileUrl.isEmpty) continue;

      apiRecordIds.add(recordId);
      final galleryAssetId = _galleryAssetIdForRecord(recordId);
      fromApi.add(
        AppPhoto(
          id: 'record_$recordId',
          localPath: '',
          recordId: recordId,
          remoteUrl: fileUrl,
          galleryAssetId: galleryAssetId,
          createdAtMs: _parseCreatedAt(record['created_at']) ?? 0,
        ),
      );
    }

    fromApi.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

    final cached = <AppPhoto>[];
    for (final photo in fromApi) {
      cached.add(
        await _materializeCloudPhotoCache(
          photo,
          previous: previousByRecordId[photo.serverRecordId],
          localCapture: _findLocalPhotoByRecordId(photo.serverRecordId),
        ),
      );
    }

    final merged = await _mergeLocalCapturesIntoCloudGallery(cached);

    final activeRecordIds = {
      ...apiRecordIds,
      for (final photo in merged)
        if (photo.serverRecordId != null) photo.serverRecordId!,
    };
    await _pruneCloudCache(activeRecordIds);
    _cloudGalleryPhotos = merged;
    await _persistCloudGalleryIndex();
  }

  /// 接口列表有延迟时，补上本地已上传但尚未出现在列表里的成片
  Future<List<AppPhoto>> _mergeLocalCapturesIntoCloudGallery(
    List<AppPhoto> fromApi, {
    bool includePendingLocals = true,
  }) async {
    final byRecordId = <int, AppPhoto>{
      for (final photo in fromApi)
        if (photo.serverRecordId != null) photo.serverRecordId!: photo,
    };
    final merged = List<AppPhoto>.from(fromApi);

    for (final local in _photos) {
      if (!local.hasLocalFile) continue;

      final recordId = local.recordId;
      final remoteUrl = local.remoteUrl;
      if (recordId != null &&
          recordId > 0 &&
          remoteUrl != null &&
          remoteUrl.isNotEmpty) {
        if (byRecordId.containsKey(recordId)) continue;

        merged.removeWhere((photo) => photo.id == local.id);

        final cloudPhoto = AppPhoto(
          id: 'record_$recordId',
          localPath: local.localPath,
          recordId: recordId,
          remoteUrl: remoteUrl,
          galleryAssetId: local.galleryAssetId,
          createdAtMs: local.createdAtMs,
          captureLatitude: local.captureLatitude,
          captureLongitude: local.captureLongitude,
        );
        final materialized = await _materializeCloudPhotoCache(
          cloudPhoto,
          localCapture: local,
        );
        merged.add(materialized);
        byRecordId[recordId] = materialized;
        continue;
      }

      // 上传尚未完成时先用本地成片占位，避免连拍进相册漏图
      if (!includePendingLocals) continue;
      if (merged.any((photo) => photo.id == local.id)) continue;
      final ageMs = DateTime.now().millisecondsSinceEpoch - local.createdAtMs;
      if (ageMs > const Duration(hours: 1).inMilliseconds) continue;
      merged.add(local);
    }

    merged.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return merged;
  }

  /// 删除应用内本地照片文件与索引（不影响云端记录）
  Future<void> clearLocalPhotos() async {
    await init();

    for (final photo in List<AppPhoto>.from(_photos)) {
      if (!photo.hasLocalFile) continue;
      try {
        final file = File(photo.localPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }

    try {
      final dir = await _photosDirectory();
      await for (final entity in dir.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
    } catch (_) {}

    _photos.removeWhere((photo) => photo.hasLocalFile);
    await _persistIndex();
  }

  /// 后台写入系统相册并更新索引（串行队列，避免连拍时并发 saveImage 导致 OOM）
  Future<void> syncToSystemGallery(String photoId) {
    final completer = Completer<void>();
    _gallerySyncTail = _gallerySyncTail
        .then((_) => _syncToSystemGalleryImpl(photoId))
        .then((_) {
      if (!completer.isCompleted) completer.complete();
    }).catchError((Object e, StackTrace stack) {
      debugPrint('PhotoGalleryService: syncToSystemGallery error: $e');
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  Future<void> _syncToSystemGalleryImpl(String photoId) async {
    await init();
    final index = _photos.indexWhere((p) => p.id == photoId);
    if (index < 0 || _photos[index].galleryAssetId != null) return;

    if (!await ensurePermission()) {
      return;
    }

    final photo = _photos[index];
    final galleryAssetId = await _saveToSystemGallery(photo.localPath, photo.id);
    if (galleryAssetId == null) return;

    _photos[index] = photo.copyWith(galleryAssetId: galleryAssetId);
    final recordId = _photos[index].recordId;
    if (recordId != null && recordId > 0) {
      _rememberGalleryAsset(recordId, galleryAssetId);
      _rememberCaptureId(recordId, photoId);
    }
    await _persistIndex();
  }

  String _nextPhotoId() {
    _saveSeq += 1;
    return '${DateTime.now().microsecondsSinceEpoch}_$_saveSeq';
  }

  Future<String?> _saveToSystemGallery(String localPath, String id) async {
    final title = 'pet_ai_$id';
    try {
      final entity = await PhotoManager.editor.saveImageWithPath(
        localPath,
        title: title,
        relativePath: _albumFolder,
      );
      return entity.id;
    } catch (_) {}

    try {
      final entity = await PhotoManager.editor.saveImageWithPath(
        localPath,
        title: title,
      );
      return entity.id;
    } catch (_) {
      return null;
    }
  }

  Future<({bool ok, String msg})> deletePhoto(String id) async {
    await init();
    final cloudIndex =
        _cloudGalleryPhotos.indexWhere((photo) => photo.id == id);
    if (cloudIndex < 0) {
      return (ok: false, msg: '照片不存在');
    }

    final photo = _cloudGalleryPhotos[cloudIndex];
    final recordId = await _resolveDeleteRecordId(photo);
    var msg = '';

    if (recordId != null) {
      final result = await CameraRecordStore.instance.deleteRecord(recordId);
      if (!result.ok) {
        return (ok: false, msg: result.msg);
      }
      msg = result.msg;
    }

    _cloudGalleryPhotos.removeAt(cloudIndex);
    await _removeLocalPhotosLinkedTo(photo);
    final cacheRecordId = photo.serverRecordId;
    if (cacheRecordId != null && cacheRecordId > 0) {
      await _deleteCacheForRecord(cacheRecordId);
    }
    await _persistCloudGalleryIndex();
    return (ok: true, msg: msg);
  }

  /// 批量删除，返回成功删除的数量与接口 msg（云端记录一次接口调用）
  Future<({int deleted, String msg})> deletePhotos(List<String> ids) async {
    await init();
    if (ids.isEmpty) {
      return (deleted: 0, msg: '');
    }

    final photos = <AppPhoto>[];
    for (final id in ids) {
      final cloudIndex =
          _cloudGalleryPhotos.indexWhere((photo) => photo.id == id);
      if (cloudIndex < 0) {
        return (deleted: 0, msg: '照片不存在');
      }
      photos.add(_cloudGalleryPhotos[cloudIndex]);
    }

    final recordIds = <int>{};
    for (final photo in photos) {
      final recordId = await _resolveDeleteRecordId(photo);
      if (recordId != null && recordId > 0) {
        recordIds.add(recordId);
      }
    }

    var msg = '';
    if (recordIds.isNotEmpty) {
      final result = await CameraRecordStore.instance.deleteRecords(recordIds);
      if (!result.ok) {
        return (deleted: 0, msg: result.msg);
      }
      msg = result.msg;
    }

    for (final photo in photos) {
      final cloudIndex =
          _cloudGalleryPhotos.indexWhere((item) => item.id == photo.id);
      if (cloudIndex >= 0) {
        _cloudGalleryPhotos.removeAt(cloudIndex);
      }
      await _removeLocalPhotosLinkedTo(photo);
      final cacheRecordId = photo.serverRecordId;
      if (cacheRecordId != null && cacheRecordId > 0) {
        await _deleteCacheForRecord(cacheRecordId);
      }
    }
    await _persistCloudGalleryIndex();
    return (deleted: photos.length, msg: msg);
  }

  /// 删除全部照片：先调 deleteAllCameraRecords，再清云端列表与关联本地缓存
  Future<({int deleted, String msg})> deleteAllPhotos() async {
    await init();
    final count = _cloudGalleryPhotos.length;
    if (count == 0) {
      return (deleted: 0, msg: '');
    }

    final result = await CameraRecordStore.instance.deleteAllRecords();
    if (!result.ok) {
      return (deleted: 0, msg: result.msg);
    }

    for (final photo in List<AppPhoto>.from(_cloudGalleryPhotos)) {
      await _removeLocalPhotosLinkedTo(photo);
    }
    _cloudGalleryPhotos.clear();
    await _clearCloudCache();
    await _persistCloudGalleryIndex();
    return (deleted: count, msg: result.msg);
  }

  List<AppPhoto> _linkedLocalPhotos(AppPhoto cloudPhoto) {
    final recordId = cloudPhoto.serverRecordId;
    final linked = recordId != null
        ? _photos.where((photo) => photo.serverRecordId == recordId).toList()
        : <AppPhoto>[];
    if (recordId != null) {
      final capture = _findLocalPhotoByRecordId(recordId);
      if (capture != null &&
          !linked.any((photo) => photo.id == capture.id)) {
        linked.insert(0, capture);
      }
    }
    if (linked.isEmpty && cloudPhoto.hasLocalFile) {
      linked.add(cloudPhoto);
    }
    return linked;
  }

  bool _isCapturePhotoId(String id) => !id.startsWith('record_');

  Future<void> _removeLocalPhotosLinkedTo(
    AppPhoto cloudPhoto, {
    bool? deleteSystemGallery,
  }) async {
    final recordId = cloudPhoto.serverRecordId;
    final linked = _linkedLocalPhotos(cloudPhoto);
    final shouldDeleteFromSystemGallery = deleteSystemGallery ??
        !_isAlbumImportRecord(recordId);

    final assetIds = _collectGalleryAssetIds(
      cloudPhoto: cloudPhoto,
      linked: linked,
    );
    final captureIds = _collectCaptureIds(
      cloudPhoto: cloudPhoto,
      linked: linked,
    );
    if (shouldDeleteFromSystemGallery) {
      await _deleteFromSystemGallery(
        assetIds: assetIds,
        captureIds: captureIds,
      );
    }

    if (recordId != null && recordId > 0) {
      _forgetGalleryAsset(recordId);
      _forgetCaptureId(recordId);
      _forgetAlbumUpload(recordId);
    }

    for (final photo in linked) {
      await _deleteLocalFileOnly(photo);
      _photos.removeWhere((item) => item.id == photo.id);
    }
    await _persistIndex();
  }

  Set<String> _collectGalleryAssetIds({
    required AppPhoto cloudPhoto,
    required List<AppPhoto> linked,
  }) {
    final assetIds = <String>{};
    void add(String? id) {
      if (id != null && id.isNotEmpty) assetIds.add(id);
    }

    add(cloudPhoto.galleryAssetId);
    final recordId = cloudPhoto.serverRecordId;
    if (recordId != null && recordId > 0) {
      add(_galleryAssetByRecordId[recordId]);
    }
    for (final photo in linked) {
      add(photo.galleryAssetId);
    }
    return assetIds;
  }

  Set<String> _collectCaptureIds({
    required AppPhoto cloudPhoto,
    required List<AppPhoto> linked,
  }) {
    final captureIds = <String>{};
    void add(String? id) {
      if (id != null && id.isNotEmpty) captureIds.add(id);
    }

    final recordId = cloudPhoto.serverRecordId;
    if (recordId != null && recordId > 0) {
      add(_captureIdByRecordId[recordId]);
    }
    for (final photo in linked) {
      if (_isCapturePhotoId(photo.id)) {
        add(photo.id);
      }
    }
    return captureIds;
  }

  /// 返回 false 表示用户取消或系统相册删除失败。iOS 仅保存到系统相册，不执行删除。
  Future<bool> _deleteFromSystemGallery({
    required Set<String> assetIds,
    required Set<String> captureIds,
  }) async {
    if (Platform.isIOS) return true;

    final validCaptureIds =
        captureIds.where(_isCapturePhotoId).toSet();
    final ids = Set<String>.from(assetIds);
    if (ids.isEmpty && validCaptureIds.isEmpty) return true;

    if (!await ensurePermission()) return false;

    await GalleryMediaChannel.deleteAppPhotos(
      assetIds: ids.toList(),
      captureIds: validCaptureIds.toList(),
    );
    return true;
  }

  Future<void> _deleteLocalFileOnly(AppPhoto photo) async {
    try {
      final file = File(photo.localPath);
      if (photo.hasLocalFile && await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<Directory> _cloudCacheDirectory() async {
    if (_cloudCacheDir != null && await _cloudCacheDir!.exists()) {
      return _cloudCacheDir!;
    }
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _cloudCacheFolder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cloudCacheDir = dir;
    return dir;
  }

  Future<String> _cachePathForRecord(int recordId) async {
    final dir = await _cloudCacheDirectory();
    return p.join(dir.path, 'record_$recordId.jpg');
  }

  AppPhoto? _findLocalPhotoByRecordId(int? recordId) {
    if (recordId == null || recordId <= 0) return null;
    for (final photo in _photos) {
      if (photo.recordId == recordId) return photo;
    }
    return null;
  }

  /// 调色盘读 EXIF 时优先本地成片（含 GPS），避免 cloud_cache 云端图无位置
  Future<String?> metadataExifPathFor(AppPhoto photo) async {
    await init();

    final recordId = photo.serverRecordId;
    if (recordId != null) {
      final capture = _findLocalPhotoByRecordId(recordId);
      if (capture != null && capture.hasLocalFile) {
        final file = File(capture.localPath);
        if (await file.exists()) return capture.localPath;
      }
    }

    if (photo.hasLocalFile && !_isCloudCachePath(photo.localPath)) {
      final file = File(photo.localPath);
      if (await file.exists()) return photo.localPath;
    }

    if (photo.hasLocalFile) {
      final file = File(photo.localPath);
      if (await file.exists()) return photo.localPath;
    }

    return null;
  }

  /// 调色盘展示地点时优先读快门时缓存的坐标
  Future<({double lat, double lng})?> captureCoordinatesFor(AppPhoto photo) async {
    await init();
    final direct = _coordinatesFromPhoto(photo);
    if (direct != null) return direct;

    final recordId = photo.serverRecordId;
    if (recordId == null) return null;
    return _coordinatesFromPhoto(_findLocalPhotoByRecordId(recordId));
  }

  ({double lat, double lng})? _coordinatesFromPhoto(AppPhoto? photo) {
    if (photo == null || !photo.hasCaptureCoordinates) return null;
    return (lat: photo.captureLatitude!, lng: photo.captureLongitude!);
  }

  AppPhoto _mergeCaptureMetadata(AppPhoto photo, AppPhoto? localCapture) {
    if (localCapture == null) return photo;
    return photo.copyWith(
      captureLatitude: localCapture.captureLatitude ?? photo.captureLatitude,
      captureLongitude: localCapture.captureLongitude ?? photo.captureLongitude,
    );
  }

  bool _isCloudCachePath(String path) => path.contains(_cloudCacheFolder);

  Future<AppPhoto> _materializeCloudPhotoCache(
    AppPhoto photo, {
    AppPhoto? previous,
    AppPhoto? localCapture,
  }) async {
    final recordId = photo.serverRecordId;
    if (recordId == null || recordId <= 0) return photo;

    final cachePath = await _cachePathForRecord(recordId);
    final cacheFile = File(cachePath);
    if (await cacheFile.exists() && await cacheFile.length() > 0) {
      return _withGalleryAssetId(
        photo.copyWith(localPath: cachePath),
        localCapture,
        previous,
      );
    }

    if (previous != null && previous.hasLocalFile) {
      final previousPath = previous.localPath;
      if (previousPath != cachePath) {
        final previousFile = File(previousPath);
        if (await previousFile.exists()) {
          final copied = await _copyFileToCache(previousFile, cachePath);
          if (copied) {
            return _withGalleryAssetId(
              photo.copyWith(localPath: cachePath),
              localCapture,
              previous,
            );
          }
        }
      } else if (await cacheFile.exists()) {
        return _withGalleryAssetId(
          photo.copyWith(localPath: cachePath),
          localCapture,
          previous,
        );
      }
    }

    if (localCapture != null && localCapture.hasLocalFile) {
      final localFile = File(localCapture.localPath);
      if (await localFile.exists()) {
        final copied = await _copyFileToCache(localFile, cachePath);
        if (copied) {
          return _withGalleryAssetId(
            photo.copyWith(localPath: cachePath),
            localCapture,
            previous,
          );
        }
      }
    }

    final url = photo.remoteUrl;
    if (url != null && url.isNotEmpty) {
      final downloaded = await _downloadToCache(url, cachePath);
      if (downloaded) return _withGalleryAssetId(photo, localCapture, previous);
    }

    return _withGalleryAssetId(photo, localCapture, previous);
  }

  AppPhoto _withGalleryAssetId(
    AppPhoto photo,
    AppPhoto? localCapture,
    AppPhoto? previous,
  ) {
    var result = _mergeCaptureMetadata(photo, localCapture);
    if (result.galleryAssetId != null) return result;
    final recordId = result.serverRecordId;
    final assetId = localCapture?.galleryAssetId ??
        previous?.galleryAssetId ??
        (recordId != null ? _galleryAssetByRecordId[recordId] : null);
    if (assetId == null) return result;
    return result.copyWith(galleryAssetId: assetId);
  }

  String? _galleryAssetIdForRecord(int recordId) {
    final mapped = _galleryAssetByRecordId[recordId];
    if (mapped != null) return mapped;
    return _findLocalPhotoByRecordId(recordId)?.galleryAssetId;
  }

  void _rememberGalleryAsset(int recordId, String assetId) {
    _galleryAssetByRecordId[recordId] = assetId;
    unawaited(_persistGalleryAssetMap());
  }

  void _rememberCaptureId(int recordId, String captureId) {
    _captureIdByRecordId[recordId] = captureId;
    unawaited(_persistGalleryAssetMap());
  }

  void _forgetGalleryAsset(int recordId) {
    if (!_galleryAssetByRecordId.containsKey(recordId)) return;
    _galleryAssetByRecordId.remove(recordId);
    unawaited(_persistGalleryAssetMap());
  }

  void _forgetCaptureId(int recordId) {
    if (!_captureIdByRecordId.containsKey(recordId)) return;
    _captureIdByRecordId.remove(recordId);
    unawaited(_persistGalleryAssetMap());
  }

  bool _isAlbumImportRecord(int? recordId) {
    if (recordId == null || recordId <= 0) return false;
    if (_albumUploadRecordIds.contains(recordId)) return true;
    return _findLocalPhotoByRecordId(recordId)?.fromAlbumUpload ?? false;
  }

  void _rememberAlbumUpload(int recordId) {
    _albumUploadRecordIds.add(recordId);
    unawaited(_persistGalleryAssetMap());
  }

  void _forgetAlbumUpload(int recordId) {
    if (!_albumUploadRecordIds.contains(recordId)) return;
    _albumUploadRecordIds.remove(recordId);
    unawaited(_persistGalleryAssetMap());
  }

  void _rebuildGalleryAssetMapFromPhotos() {
    for (final photo in _photos) {
      final recordId = photo.recordId;
      if (recordId == null || recordId <= 0) continue;
      if (photo.fromAlbumUpload) {
        _albumUploadRecordIds.add(recordId);
      }
      final assetId = photo.galleryAssetId;
      if (assetId != null && assetId.isNotEmpty) {
        _galleryAssetByRecordId[recordId] = assetId;
      }
      if (photo.id.isNotEmpty) {
        _captureIdByRecordId[recordId] = photo.id;
      }
    }
  }

  Future<void> _loadGalleryAssetMap() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final mapFile = File(p.join(base.path, _galleryAssetMapFileName));
      if (!await mapFile.exists()) return;

      final raw = jsonDecode(await mapFile.readAsString());
      if (raw is! Map) return;

      final albumUploadIds = raw['__albumUploadRecordIds__'];
      if (albumUploadIds is List) {
        for (final id in albumUploadIds) {
          final recordId = _asInt(id);
          if (recordId > 0) {
            _albumUploadRecordIds.add(recordId);
          }
        }
      }

      raw.forEach((key, value) {
        if (key == '__albumUploadRecordIds__') return;
        final recordId = int.tryParse(key.toString());
        if (recordId == null || recordId <= 0) return;

        if (value is Map) {
          final assetId = value['assetId']?.toString();
          final captureId = value['captureId']?.toString();
          if (assetId != null && assetId.isNotEmpty) {
            _galleryAssetByRecordId[recordId] = assetId;
          }
          if (captureId != null && captureId.isNotEmpty) {
            _captureIdByRecordId[recordId] = captureId;
          }
          return;
        }

        final assetId = value?.toString();
        if (assetId != null && assetId.isNotEmpty) {
          _galleryAssetByRecordId[recordId] = assetId;
        }
      });
    } catch (_) {}
  }

  Future<void> _persistGalleryAssetMap() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final mapFile = File(p.join(base.path, _galleryAssetMapFileName));
      final encoded = <String, dynamic>{};
      if (_albumUploadRecordIds.isNotEmpty) {
        encoded['__albumUploadRecordIds__'] =
            _albumUploadRecordIds.toList()..sort();
      }
      final recordIds = {
        ..._galleryAssetByRecordId.keys,
        ..._captureIdByRecordId.keys,
      };
      for (final recordId in recordIds) {
        final assetId = _galleryAssetByRecordId[recordId];
        final captureId = _captureIdByRecordId[recordId];
        if ((assetId == null || assetId.isEmpty) &&
            (captureId == null || captureId.isEmpty)) {
          continue;
        }
        encoded['$recordId'] = {
          if (assetId != null && assetId.isNotEmpty) 'assetId': assetId,
          if (captureId != null && captureId.isNotEmpty) 'captureId': captureId,
        };
      }
      await mapFile.writeAsString(jsonEncode(encoded));
    } catch (_) {}
  }

  Future<bool> _copyFileToCache(File source, String cachePath) async {
    try {
      final dest = File(cachePath);
      await dest.parent.create(recursive: true);
      if (source.path == cachePath) return true;
      await source.copy(cachePath);
      return await dest.exists() && await dest.length() > 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _downloadToCache(String url, String cachePath) async {
    try {
      final dest = File(cachePath);
      await dest.parent.create(recursive: true);
      final dio = Dio();
      await dio.download(url, cachePath);
      return await dest.exists() && await dest.length() > 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> _deleteCacheForRecord(int recordId) async {
    try {
      final cachePath = await _cachePathForRecord(recordId);
      final file = File(cachePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> _pruneCloudCache(Set<int> activeRecordIds) async {
    try {
      final dir = await _cloudCacheDirectory();
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = p.basenameWithoutExtension(entity.path);
        if (!name.startsWith('record_')) continue;
        final recordId = int.tryParse(name.substring('record_'.length));
        if (recordId == null || !activeRecordIds.contains(recordId)) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }

  Future<void> _clearCloudCache() async {
    try {
      final dir = await _cloudCacheDirectory();
      await for (final entity in dir.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }

  Future<void> _persistCloudGalleryIndex() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final indexFile = File(p.join(base.path, _cloudGalleryIndexFileName));
      final jsonList = _cloudGalleryPhotos.map((photo) => photo.toJson()).toList();
      await indexFile.writeAsString(jsonEncode(jsonList));
    } catch (_) {}
  }

  Future<void> _loadCloudGalleryIndex() async {
    _cloudGalleryPhotos = [];
    try {
      final base = await getApplicationDocumentsDirectory();
      final indexFile = File(p.join(base.path, _cloudGalleryIndexFileName));
      if (!await indexFile.exists()) return;

      final list = jsonDecode(await indexFile.readAsString()) as List<dynamic>;
      for (final item in list) {
        if (item is! Map) continue;
        _cloudGalleryPhotos.add(
          AppPhoto.fromJson(Map<String, dynamic>.from(item)),
        );
      }
      _cloudGalleryPhotos.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

      final hydrated = <AppPhoto>[];
      for (final photo in _cloudGalleryPhotos) {
        hydrated.add(await _resolveDisplayPhoto(photo) ?? photo);
      }
      _cloudGalleryPhotos = hydrated;
    } catch (_) {
      _cloudGalleryPhotos = [];
    }
  }

  Future<Directory> _photosDirectory() async {
    if (_cachedPhotosDir != null && await _cachedPhotosDir!.exists()) {
      return _cachedPhotosDir!;
    }
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'photos'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cachedPhotosDir = dir;
    return dir;
  }

  Future<void> _loadIndex() async {
    _photos.clear();
    try {
      final base = await getApplicationDocumentsDirectory();
      final indexFile = File(p.join(base.path, _indexFileName));
      if (!await indexFile.exists()) return;

      final list = jsonDecode(await indexFile.readAsString()) as List<dynamic>;
      for (final item in list) {
        final photo = AppPhoto.fromJson(item as Map<String, dynamic>);
        final recordId = photo.recordId;
        final assetId = photo.galleryAssetId;
        if (recordId != null &&
            recordId > 0 &&
            assetId != null &&
            assetId.isNotEmpty) {
          _galleryAssetByRecordId[recordId] = assetId;
        }
        if (recordId != null && recordId > 0 && photo.id.isNotEmpty) {
          _captureIdByRecordId[recordId] = photo.id;
        }
        if (recordId != null && recordId > 0 && photo.fromAlbumUpload) {
          _albumUploadRecordIds.add(recordId);
        }
        if (recordId != null && recordId > 0 && photo.id.isNotEmpty) {
          _captureIdByRecordId[recordId] = photo.id;
        }
        if (photo.hasLocalFile) {
          if (await File(photo.localPath).exists()) {
            _photos.add(photo);
          }
        } else if (photo.remoteUrl != null && photo.remoteUrl!.isNotEmpty) {
          _photos.add(photo);
        }
      }
      _photos.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    } catch (_) {}
  }

  Future<void> _persistIndex() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final indexFile = File(p.join(base.path, _indexFileName));
      final jsonList = _photos.map((photo) => photo.toJson()).toList();
      await indexFile.writeAsString(jsonEncode(jsonList));
    } catch (_) {}
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static int? _parseCreatedAt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    return parsed?.millisecondsSinceEpoch;
  }

  /// 列表 id = 删除 record_id；本地未缓存时按 file_url 反查
  Future<int?> _resolveDeleteRecordId(AppPhoto photo) async {
    final direct = photo.serverRecordId;
    if (direct != null && direct > 0) return direct;

    final store = CameraRecordStore.instance;
    final byUrl = store.findRecordIdByFileUrl(photo.remoteUrl);
    if (byUrl != null && byUrl > 0) return byUrl;

    if (!store.listLoaded) {
      try {
        await store.fetchList(recordType: 1);
      } catch (_) {
        return null;
      }
    }
    return store.findRecordIdByFileUrl(photo.remoteUrl);
  }
}
