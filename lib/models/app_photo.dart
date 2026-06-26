/// 应用内保存的照片记录（本地 + 云端摄像头记录）
class AppPhoto {
  final String id;
  final String localPath;
  final String? galleryAssetId;
  final int createdAtMs;
  final int? recordId;
  final String? remoteUrl;

  const AppPhoto({
    required this.id,
    required this.localPath,
    this.galleryAssetId,
    required this.createdAtMs,
    this.recordId,
    this.remoteUrl,
  });

  bool get hasLocalFile => localPath.isNotEmpty;

  String? get displaySource {
    if (hasLocalFile) return localPath;
    final url = remoteUrl;
    if (url != null && url.isNotEmpty) return url;
    return null;
  }

  bool get isRemoteOnly => !hasLocalFile && remoteUrl != null && remoteUrl!.isNotEmpty;

  /// 摄像头记录列表项 id（= 删除接口 record_id）
  int? get serverRecordId {
    if (recordId != null && recordId! > 0) return recordId;
    if (id.startsWith('record_')) {
      return int.tryParse(id.substring('record_'.length));
    }
    return null;
  }

  factory AppPhoto.fromJson(Map<String, dynamic> json) {
    return AppPhoto(
      id: json['id'] as String,
      localPath: json['localPath'] as String? ?? '',
      galleryAssetId: json['galleryAssetId'] as String?,
      createdAtMs: json['createdAtMs'] as int,
      recordId: _readInt(json['recordId']),
      remoteUrl: json['remoteUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'localPath': localPath,
        if (galleryAssetId != null) 'galleryAssetId': galleryAssetId,
        'createdAtMs': createdAtMs,
        if (recordId != null) 'recordId': recordId,
        if (remoteUrl != null) 'remoteUrl': remoteUrl,
      };

  AppPhoto copyWith({
    String? id,
    String? localPath,
    String? galleryAssetId,
    int? createdAtMs,
    int? recordId,
    String? remoteUrl,
    bool clearRecordId = false,
    bool clearRemoteUrl = false,
  }) {
    return AppPhoto(
      id: id ?? this.id,
      localPath: localPath ?? this.localPath,
      galleryAssetId: galleryAssetId ?? this.galleryAssetId,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      recordId: clearRecordId ? null : (recordId ?? this.recordId),
      remoteUrl: clearRemoteUrl ? null : (remoteUrl ?? this.remoteUrl),
    );
  }

  static int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
