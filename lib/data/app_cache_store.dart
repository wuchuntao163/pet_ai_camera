import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api.dart';
import '../constants/app_branding.dart';

/// 启动接口数据缓存（getConfig / getAppInfo / nav / getLanguage）
class AppCacheStore extends ChangeNotifier {
  AppCacheStore._();

  static final AppCacheStore instance = AppCacheStore._();
  static const _keyCachedConfig = 'cached_get_config';

  SharedPreferences? _prefs;
  dynamic _config;
  dynamic _info;
  List<dynamic> navList = [];
  List<dynamic> languageList = [];
  List<dynamic> navLangList = [];

  bool configLoading = false;
  bool configLoaded = false;

  String _localAppVersion = '1.0.0';

  dynamic get config => _config;
  dynamic get info => _info;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    final cached = _prefs!.getString(_keyCachedConfig);
    if (cached != null && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached);
        await setConfig(decoded, persist: false, markLoaded: false);
      } catch (_) {}
    }
  }

  Future<void>? _configFuture;

  Future<void> fetchConfig({bool force = false}) {
    if (force) {
      _configFuture = null;
      if (!configLoading) configLoaded = false;
    }
    if (configLoaded && !force) return Future.value();
    return _configFuture ??= _fetchConfig();
  }

  Future<void> _fetchConfig() async {
    configLoading = true;
    notifyListeners();
    try {
      final res = await Api.get(ApiPaths.getConfig);
      await setConfig(res.data);
    } on ApiException catch (_) {
    } catch (_) {
    } finally {
      configLoading = false;
      if (!configLoaded && _config != null) {
        configLoaded = true;
      }
      notifyListeners();
      _configFuture = null;
    }
  }

  Future<void> setConfig(
    dynamic data, {
    bool persist = true,
    bool markLoaded = true,
  }) async {
    final parsed = _extractConfig(data);
    if (parsed == null) {
      return;
    }
    _config = parsed;
    if (markLoaded) configLoaded = true;
    if (persist && data != null) {
      _prefs ??= await SharedPreferences.getInstance();
      try {
        await _prefs!.setString(_keyCachedConfig, jsonEncode(data));
      } catch (_) {}
    }
    notifyListeners();
  }

  static Map<String, dynamic>? _extractConfig(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['config'] is Map) {
      return Map<String, dynamic>.from(map['config'] as Map);
    }
    return map;
  }

  void setAppInfo(dynamic data) {
    _info = data is Map ? data['info'] : null;
    notifyListeners();
  }

  String get displayAppName {
    final info = _info;
    if (info is Map) {
      final name = info['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return AppBranding.appName;
  }

  String? get appLogoUrl {
    final info = _info;
    if (info is Map) {
      final logo = info['logo']?.toString().trim();
      if (logo != null && logo.isNotEmpty) return logo;
    }
    return null;
  }

  /// getConfig → data.config 中的字符串字段
  String? configString(String key) {
    final config = _config;
    if (config is! Map) return null;
    final value = config[key]?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  /// 推荐分享链接
  String? get shareUrl => configString('share_url');

  /// 联系客服（企业微信等）
  String? get customerServiceLink => configString('day_customer_service_link');

  /// 隐私政策链接（后台 privacy_url 优先，否则使用默认地址）
  String get privacyPolicyUrl =>
      configString('privacy_url') ??
      configString('privacy_policy_url') ??
      AppBranding.privacyPolicyUrl;

  /// 本机安装版本（PackageInfo，启动时写入）
  String get localAppVersion => _localAppVersion;

  void setLocalVersion(String version) {
    final trimmed = version.trim();
    if (trimmed.isEmpty || trimmed == _localAppVersion) return;
    _localAppVersion = trimmed;
    notifyListeners();
  }

  /// 服务端最新版本（config.app_version）
  String? get remoteAppVersion => configString('app_version');

  /// 设置页展示的本机版本
  String get appVersion => _localAppVersion;

  /// 版本更新提示（HTML，来自 config.update_tips）
  String? get updateTips => configString('update_tips');

  String? get androidStoreUrl => configString('android_store_url');

  String? get iosStoreUrl => configString('ios_store_url');

  void setNavList(dynamic data) {
    navList = data is List ? data : [];
    notifyListeners();
  }

  void setLanguage(dynamic data) {
    if (data is Map) {
      languageList = data['list'] is List ? data['list'] : [];
      navLangList = data['nav_lang'] is List ? data['nav_lang'] : [];
    } else {
      languageList = [];
      navLangList = [];
    }
    notifyListeners();
  }

  /// 默认语言 ID（用于音效等接口）
  int? get defaultLanguageId {
    if (languageList.isEmpty) return null;
    final first = languageList.first;
    if (first is! Map) return null;
    final id = first['id'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id);
    return null;
  }

  void clear() {
    _config = null;
    _info = null;
    navList = [];
    languageList = [];
    navLangList = [];
    configLoading = false;
    configLoaded = false;
    _configFuture = null;
    _prefs?.remove(_keyCachedConfig);
    notifyListeners();
  }
}
