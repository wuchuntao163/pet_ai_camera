/// 用户录制的自定义音效（本地静态数据，后续接入接口）
class RecordedSound {
  final String id;
  final String name;
  final String filePath;
  final DateTime createdAt;

  const RecordedSound({
    required this.id,
    required this.name,
    required this.filePath,
    required this.createdAt,
  });
}
