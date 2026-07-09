import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../data/camera_record_store.dart';
import '../data/app_cache_store.dart';
import '../data/camera_sound_store.dart';
import '../utils/app_update_util.dart';

/// App 启动后执行（须在 runApp 之后）
class AppLaunch extends ChangeNotifier {
  AppLaunch._();

  static final AppLaunch instance = AppLaunch._();

  final _cache = AppCacheStore.instance;

  bool _ready = false;
  bool get ready => _ready;

  /// 由 [MainApp] 首帧回调触发，勿在 main 里 await
  Future<void> onLaunch() async {
    await Api.init();
    await _cache.init();

    await Future.wait([_cache.fetchConfig(), _loginByUuid()]);

    await AppUpdateUtil.init();

    await _fetchAppInfo();
    await _fetchNav();
    await _fetchLanguage();

    await CameraSoundStore.instance.fetchCategories(
      languageId: _cache.defaultLanguageId,
    );
    await CameraSoundStore.instance.refreshSidebarEffects(
      languageId: _cache.defaultLanguageId,
    );
    unawaited(_prefetchCameraRecords());

    _ready = true;
    notifyListeners();
  }

  Future<void> _loginByUuid() async {
    try {
      final uuid = await AuthSessionStore.instance.getOrCreateUuid();
      final res = await Api.post(ApiPaths.loginByUuid, data: {'uuid': uuid});
      final data = res.data;
      if (data != null) {
        await AuthSessionStore.instance.saveData(data);
      }
    } on ApiException catch (_) {}
  }

  Future<void> _fetchNav() async {
    try {
      final res = await Api.get(ApiPaths.nav, query: {'type': 2});
      _cache.setNavList(res.data);
    } on ApiException catch (_) {}
  }

  Future<void> _fetchAppInfo() async {
    try {
      final res = await Api.get(ApiPaths.getAppInfo);
      _cache.setAppInfo(res.data);
    } on ApiException catch (_) {}
  }

  Future<void> _prefetchCameraRecords() async {
    try {
      await CameraRecordStore.instance.fetchList(recordType: 1);
    } on ApiException catch (_) {
    }
  }

  Future<void> _fetchLanguage() async {
    try {
      final res = await Api.get(ApiPaths.getLanguage);
      _cache.setLanguage(res.data);
    } on ApiException catch (_) {}
  }
}
