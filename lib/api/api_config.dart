/// 接口环境与公共配置（见项目根目录 [api.md]）
class ApiConfig {
  ApiConfig._();

  /// 请求域名
  static const String baseUrl = 'https://pet.laowaidrivetest.com';

  /// 应用 ID（上线前替换为后台分配值）
  static const int appId = 8;

  /// 来源：1-小程序/H5，2-App（对齐 uniapp source）
  static const int source = 2;

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Debug 下打印请求日志
  static const bool enableLog = true;
}
