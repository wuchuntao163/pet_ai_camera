import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../services/file_upload_service.dart';

/// 相机拍摄记录：保存、列表、删除
class CameraRecordStore extends ChangeNotifier {
  CameraRecordStore._();

  static final CameraRecordStore instance = CameraRecordStore._();

  final List<Map<String, dynamic>> _records = [];
  bool isLoading = false;
  bool listLoaded = false;

  List<Map<String, dynamic>> get records => List.unmodifiable(_records);

  Future<void> fetchList({int? recordType}) async {
    isLoading = true;
    notifyListeners();
    try {
      final query = <String, dynamic>{};
      if (recordType != null) query['record_type'] = recordType;
      final res = await Api.get(ApiPaths.getCameraRecords, query: query);
      _records
        ..clear()
        ..addAll(_parseList(res.data));
      listLoaded = true;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<({bool ok, String msg, int? recordId, String? fileUrl})> saveRecord({
    required String localFilePath,
    int recordType = 1,
    int? soundEffectId,
    String? thumbnailLocalPath,
    int? duration,
  }) async {
    try {
      final fileUrl = await FileUploadService.uploadFile(localFilePath);
      String? thumbnailUrl;
      if (thumbnailLocalPath != null && thumbnailLocalPath.isNotEmpty) {
        thumbnailUrl =
            await FileUploadService.uploadFile(thumbnailLocalPath);
      }

      final data = <String, dynamic>{
        'file_url': fileUrl,
        'record_type': recordType,
        if (soundEffectId != null && soundEffectId > 0)
          'sound_effect_id': soundEffectId,
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
          'thumbnail_url': thumbnailUrl,
        if (duration != null && duration > 0) 'duration': duration,
      };

      final res = await Api.post(ApiPaths.saveCameraRecord, data: data);
      final recordId = _asInt(res.data is Map ? res.data['record_id'] : null);
      if (kDebugMode) {
        debugPrint(
          '[CameraRecordStore] saveRecord ok recordId=$recordId fileUrl=$fileUrl',
        );
      }
      return (
        ok: true,
        msg: res.msg,
        recordId: recordId > 0 ? recordId : null,
        fileUrl: fileUrl,
      );
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('[CameraRecordStore] saveRecord failed: $e');
      }
      return (ok: false, msg: e.message, recordId: null, fileUrl: null);
    }
  }

  /// 列表接口返回的 [id]，即删除接口的 record_id
  static int listRecordId(Map<String, dynamic> record) => _asInt(record['id']);

  /// 按 file_url 在已拉取的列表中查找 record_id（即列表项 id）
  int? findRecordIdByFileUrl(String? fileUrl) {
    if (fileUrl == null || fileUrl.isEmpty) return null;
    for (final record in _records) {
      if (record['file_url']?.toString() == fileUrl) {
        return listRecordId(record);
      }
    }
    return null;
  }

  Future<({bool ok, String msg})> deleteRecord(int recordId) async {
    return deleteRecords([recordId]);
  }

  /// 批量删除；[recordIds] 会以 `1,2,3,4` 形式作为 record_id 一次提交
  Future<({bool ok, String msg})> deleteRecords(Iterable<int> recordIds) async {
    final ids = recordIds.where((id) => id > 0).toSet().toList()..sort();
    if (ids.isEmpty) {
      return (ok: true, msg: '');
    }
    try {
      final res = await Api.post(
        ApiPaths.deleteCameraRecord,
        data: {'record_id': ids.join(',')},
      );
      final idSet = ids.toSet();
      _records.removeWhere((e) => idSet.contains(_asInt(e['id'])));
      notifyListeners();
      return (ok: true, msg: res.msg);
    } on ApiException catch (e) {
      return (ok: false, msg: e.message);
    }
  }

  Future<({bool ok, String msg})> deleteAllRecords() async {
    try {
      final res = await Api.post(ApiPaths.deleteAllCameraRecords);
      _records.clear();
      listLoaded = true;
      notifyListeners();
      return (ok: true, msg: res.msg);
    } on ApiException catch (e) {
      return (ok: false, msg: e.message);
    }
  }

  static List<Map<String, dynamic>> _parseList(dynamic data) {
    if (data is Map && data['list'] is List) {
      return (data['list'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
