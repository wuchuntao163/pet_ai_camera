import 'package:flutter/foundation.dart';

import '../api/api.dart';

/// 用户相关接口：展示读本地缓存，需最新数据时调用 [refreshUserInfo]
class UserService {
  UserService._();

  /// 本地缓存的用户信息（loginByUuid / getUserInfo 写入 SharedPreferences）
  static Map<String, dynamic>? get cachedUserInfo {
    final data = AuthSessionStore.instance.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  /// 从服务端拉取用户信息并合并写入本地缓存
  static Future<void> refreshUserInfo() async {
    try {
      final res = await Api.get(ApiPaths.getUserInfo);
      final info = res.data;
      if (info is Map) {
        await AuthSessionStore.instance.mergeUserInfo(
          Map<String, dynamic>.from(info),
        );
      }
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('[UserService] refreshUserInfo failed: $e');
      }
    }
  }
}
