import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import '../data/camera_record_store.dart';
import '../models/app_photo.dart';

/// 管理本应用拍摄的照片：本地存储 + 系统相册同步
class PhotoGalleryService {
  static const _indexFileName = 'photos_index.json';
  static const _cloudGalleryIndexFileName = 'cloud_gallery_index.json';
  static const _cloudCacheFolder = 'cloud_cache';
  static const _albumFolder = 'Pictures/PetAiCamera';

  final List<AppPhoto> _photos = [];
  List<AppPhoto> _cloudGalleryPhotos = [];
  bool _loaded = false;
  int _saveSeq = 0;
  Directory? _cachedPhotosDir;
  Directory? _cloudCacheDir;
  ({String id, String path})? _readyCaptureSlot;
  Future<void> _uploadTail = Future.value();

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
    await _photosDirectory();
    await _cloudCacheDirectory();
    _loaded = true;
    unawaited(warmCaptureSlot());
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

  /// 原生已写入 [localPath] 后登记索引（无文件拷贝）
  Future<bool> registerCapture({
    required String id,
    required String localPath,
    int? soundEffectId,
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
      );
      _photos.insert(0, photo);
    }
    unawaited(_persistIndex());
    if (syncToGallery) {
      unawaited(syncToSystemGallery(id));
    }
    if (upload) {
      return await uploadRecordForPhoto(id, soundEffectId: soundEffectId);
    }
    return true;
  }

  /// 等待进行中的 saveCameraRecord 上传完成（相册拉取前调用）
  Future<void> waitForPendingUploads() async {
    await _uploadTail;
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
    );
    // 仅预缓存成片；相册列表以接口为准，不在此处写入展示列表
    await _materializeCloudPhotoCache(
      cloudPhoto,
      localCapture: uploaded,
    );
  }

  /// 成片落盘到最终路径后更新索引（不重复上传）
  Future<void> updateCaptureLocalPath(String id, String localPath) async {
    await init();
    final index = _photos.indexWhere((photo) => photo.id == id);
    if (index < 0) return;
    if (!await File(localPath).exists()) return;

    _photos[index] = _photos[index].copyWith(localPath: localPath);
    await _persistIndex();
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
      debugPrint(
        'PhotoGalleryService: uploadRecordForPhoto failed: ${result.msg}',
      );
      return false;
    }

    final updated = photo.copyWith(
      recordId: result.recordId,
      remoteUrl: result.fileUrl,
    );
    _photos[index] = updated;
    await _persistIndex();
    await _upsertCloudGalleryPhoto(updated);
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
    } catch (e) {
      debugPrint('PhotoGalleryService: refreshFromServer failed: $e');
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
      fromApi.add(
        AppPhoto(
          id: 'record_$recordId',
          localPath: '',
          recordId: recordId,
          remoteUrl: fileUrl,
          createdAtMs: _parseCreatedAt(record['created_at']) ?? 0,
        ),
      );
    }

    fromApi.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

    final cached = await Future.wait(
      fromApi.map(
        (photo) => _materializeCloudPhotoCache(
          photo,
          previous: previousByRecordId[photo.serverRecordId],
          localCapture: _findLocalPhotoByRecordId(photo.serverRecordId),
        ),
      ),
    );

    await _pruneCloudCache(apiRecordIds);
    _cloudGalleryPhotos = cached;
    await _persistCloudGalleryIndex();
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
      } catch (e) {
        debugPrint('PhotoGalleryService: delete local file failed: $e');
      }
    }

    try {
      final dir = await _photosDirectory();
      await for (final entity in dir.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
    } catch (e) {
      debugPrint('PhotoGalleryService: clear photos dir failed: $e');
    }

    _photos.removeWhere((photo) => photo.hasLocalFile);
    await _persistIndex();
  }

  /// 后台写入系统相册并更新索引
  Future<void> syncToSystemGallery(String photoId) async {
    await init();
    final index = _photos.indexWhere((p) => p.id == photoId);
    if (index < 0 || _photos[index].galleryAssetId != null) return;

    if (!await ensurePermission()) {
      debugPrint('PhotoGalleryService: gallery permission denied for sync');
      return;
    }

    final photo = _photos[index];
    final galleryAssetId = await _saveToSystemGallery(photo.localPath, photo.id);
    if (galleryAssetId == null) return;

    _photos[index] = photo.copyWith(galleryAssetId: galleryAssetId);
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
    } catch (e) {
      debugPrint('PhotoGalleryService: save with album path failed: $e');
    }

    try {
      final entity = await PhotoManager.editor.saveImageWithPath(
        localPath,
        title: title,
      );
      return entity.id;
    } catch (e) {
      debugPrint('PhotoGalleryService: save to gallery failed: $e');
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
    _removeLocalPhotosLinkedTo(photo);
    final cacheRecordId = photo.serverRecordId;
    if (cacheRecordId != null && cacheRecordId > 0) {
      await _deleteCacheForRecord(cacheRecordId);
    }
    await _persistCloudGalleryIndex();
    return (ok: true, msg: msg);
  }

  /// 批量删除，返回成功删除的数量与最后一条接口 msg
  Future<({int deleted, String msg})> deletePhotos(List<String> ids) async {
    var deleted = 0;
    var msg = '';
    for (final id in ids) {
      final result = await deletePhoto(id);
      if (!result.ok) {
        return (deleted: deleted, msg: result.msg);
      }
      deleted++;
      if (result.msg.isNotEmpty) msg = result.msg;
    }
    return (deleted: deleted, msg: msg);
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
      _removeLocalPhotosLinkedTo(photo);
    }
    _cloudGalleryPhotos.clear();
    await _clearCloudCache();
    await _persistCloudGalleryIndex();
    return (deleted: count, msg: result.msg);
  }

  void _removeLocalPhotosLinkedTo(AppPhoto cloudPhoto) {
    final recordId = cloudPhoto.serverRecordId;
    final linked = recordId != null
        ? _photos.where((photo) => photo.serverRecordId == recordId).toList()
        : <AppPhoto>[];
    if (linked.isEmpty && cloudPhoto.hasLocalFile) {
      linked.add(cloudPhoto);
    }
    for (final photo in linked) {
      unawaited(_deletePhotoLocalOnly(photo));
      _photos.removeWhere((item) => item.id == photo.id);
    }
  }

  Future<void> _deletePhotoLocalOnly(AppPhoto photo) async {
    if (photo.galleryAssetId != null) {
      try {
        await PhotoManager.editor.deleteWithIds([photo.galleryAssetId!]);
      } catch (e) {
        debugPrint('PhotoGalleryService: delete from gallery failed: $e');
      }
    }

    try {
      final file = File(photo.localPath);
      if (photo.hasLocalFile && await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('PhotoGalleryService: delete local file failed: $e');
    }
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
      return photo.copyWith(localPath: cachePath);
    }

    if (previous != null && previous.hasLocalFile) {
      final previousPath = previous.localPath;
      if (previousPath != cachePath) {
        final previousFile = File(previousPath);
        if (await previousFile.exists()) {
          final copied = await _copyFileToCache(previousFile, cachePath);
          if (copied) return photo.copyWith(localPath: cachePath);
        }
      } else if (await cacheFile.exists()) {
        return photo.copyWith(localPath: cachePath);
      }
    }

    if (localCapture != null && localCapture.hasLocalFile) {
      final localFile = File(localCapture.localPath);
      if (await localFile.exists()) {
        final copied = await _copyFileToCache(localFile, cachePath);
        if (copied) return photo.copyWith(localPath: cachePath);
      }
    }

    final url = photo.remoteUrl;
    if (url != null && url.isNotEmpty) {
      final downloaded = await _downloadToCache(url, cachePath);
      if (downloaded) return photo.copyWith(localPath: cachePath);
    }

    return photo;
  }

  Future<bool> _copyFileToCache(File source, String cachePath) async {
    try {
      final dest = File(cachePath);
      await dest.parent.create(recursive: true);
      if (source.path == cachePath) return true;
      await source.copy(cachePath);
      return await dest.exists() && await dest.length() > 0;
    } catch (e) {
      debugPrint('PhotoGalleryService: copy cache failed: $e');
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
    } catch (e) {
      debugPrint('PhotoGalleryService: download cache failed: $e');
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
    } catch (e) {
      debugPrint('PhotoGalleryService: delete cache failed: $e');
    }
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
    } catch (e) {
      debugPrint('PhotoGalleryService: prune cache failed: $e');
    }
  }

  Future<void> _clearCloudCache() async {
    try {
      final dir = await _cloudCacheDirectory();
      await for (final entity in dir.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
    } catch (e) {
      debugPrint('PhotoGalleryService: clear cloud cache failed: $e');
    }
  }

  Future<void> _persistCloudGalleryIndex() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final indexFile = File(p.join(base.path, _cloudGalleryIndexFileName));
      final jsonList = _cloudGalleryPhotos.map((photo) => photo.toJson()).toList();
      await indexFile.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('PhotoGalleryService: persist cloud gallery index failed: $e');
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
        if (photo.hasLocalFile) {
          if (await File(photo.localPath).exists()) {
            _photos.add(photo);
          }
        } else if (photo.remoteUrl != null && photo.remoteUrl!.isNotEmpty) {
          _photos.add(photo);
        }
      }
      _photos.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    } catch (e) {
      debugPrint('PhotoGalleryService: load index failed: $e');
    }
  }

  Future<void> _persistIndex() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final indexFile = File(p.join(base.path, _indexFileName));
      final jsonList = _photos.map((photo) => photo.toJson()).toList();
      await indexFile.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('PhotoGalleryService: persist index failed: $e');
    }
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
