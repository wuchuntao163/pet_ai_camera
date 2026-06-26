/// 统一导出（只需 import 这一个文件）
///
/// ```dart
/// import 'package:pet_ai_camera/api/api.dart';
///
/// await Api.init();
/// final res = await Api.get(ApiPaths.getConfig);
/// ```
library;

export 'api_config.dart';
export 'api_paths.dart';
export 'http.dart';
export '../data/auth_session_store.dart';
