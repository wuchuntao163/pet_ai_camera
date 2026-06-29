import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../services/file_upload_service.dart';

/// 相机音效：分类、列表、自定义音效、排序
class CameraSoundStore extends ChangeNotifier {
  CameraSoundStore._();

  static final CameraSoundStore instance = CameraSoundStore._();

  final List<Map<String, dynamic>> _categories = [];
  final Map<int, List<Map<String, dynamic>>> _effectsByCategory = {};
  List<Map<String, dynamic>> _allEffects = [];
  List<Map<String, dynamic>> _customEffects = [];

  bool categoriesLoading = false;
  bool effectsLoading = false;
  bool allEffectsLoading = false;
  bool customLoading = false;
  final Set<int> _togglingEffectIds = {};
  /// 本地 has_user_sort 缓存（接口刷新前保持右侧栏与列表一致）
  final Map<int, int> _hasUserSortOverrides = {};

  List<Map<String, dynamic>> get categories => List.unmodifiable(_categories);

  /// 接口返回且 is_show 为真的分类，保持接口原始顺序
  List<Map<String, dynamic>> get visibleCategories {
    return _categories
        .where((item) => _asInt(item['is_show']) != 0)
        .toList(growable: false);
  }

  /// 音效库 Tab 用分类（排除「我的录制」对应的自定义分类，避免重复 Tab）
  List<Map<String, dynamic>> get apiTabCategories {
    final customId = customCategoryId;
    return visibleCategories.where((item) {
      final id = _asInt(item['id']);
      if (customId != null && id == customId) return false;
      final type = _asInt(item['sound_type']);
      final name = item['name']?.toString() ?? '';
      if (type == 2 || name.contains('自定义') || name.contains('录制')) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  List<Map<String, dynamic>> get customEffects =>
      List.unmodifiable(_customEffects);

  List<Map<String, dynamic>> get allEffects => List.unmodifiable(_allEffects);

  /// 相机右侧栏：推荐音效 + 用户已添加（has_user_sort != 0），顺序与 getSoundEffects 全量列表一致
  List<Map<String, dynamic>> get sidebarEffects {
    final byId = _effectsById();
    final result = <Map<String, dynamic>>[];
    for (final raw in _allEffects) {
      final id = _asInt(raw['id']);
      if (id <= 0) continue;
      final effect = byId[id] ?? raw;
      if (isRecommended(effect) || isUserAdded(effect)) {
        result.add(effect);
      }
    }
    return result;
  }

  /// 合并全量 / 分类 / 自定义音效（同 ID 优先保留 has_user_sort=1 且 sort 更大者）
  Map<int, Map<String, dynamic>> _effectsById() {
    final byId = <int, Map<String, dynamic>>{};
    void merge(List<Map<String, dynamic>> list) {
      for (final raw in list) {
        final effect = _normalizeEffect(raw);
        final id = _asInt(effect['id']);
        if (id <= 0) continue;
        final existing = byId[id];
        if (existing == null || _shouldPreferEffect(effect, existing)) {
          byId[id] = effect;
        }
      }
    }

    merge(_allEffects);
    for (final list in _effectsByCategory.values) {
      merge(list);
    }
    merge(_customEffects);
    return byId;
  }

  bool _shouldPreferEffect(
    Map<String, dynamic> candidate,
    Map<String, dynamic> existing,
  ) {
    final hasCmp =
        hasUserSortOf(candidate).compareTo(hasUserSortOf(existing));
    if (hasCmp != 0) return hasCmp > 0;
    return _asInt(candidate['sort']).compareTo(_asInt(existing['sort'])) > 0;
  }

  bool isEffectToggling(int effectId) => _togglingEffectIds.contains(effectId);

  static bool isRecommended(Map<String, dynamic> effect) =>
      _asInt(effect['is_recommend']) != 0;

  bool isUserAdded(Map<String, dynamic> effect) => hasUserSortOf(effect) != 0;

  static bool canToggleSidebar(Map<String, dynamic> effect) =>
      !isRecommended(effect);

  int hasUserSortOf(Map<String, dynamic> effect) {
    final id = _asInt(effect['id']);
    if (_hasUserSortOverrides.containsKey(id)) {
      return _hasUserSortOverrides[id]!;
    }
    return _asInt(effect['has_user_sort']);
  }

  /// 刷新相机右侧栏所需数据（顺序拉取，避免竞态覆盖 has_user_sort）
  Future<void> refreshSidebarEffects({int? languageId}) async {
    await fetchAllEffects(languageId: languageId, pageSize: 500);
    await fetchCustomEffects(languageId: languageId);
    notifyListeners();
  }

  List<Map<String, dynamic>> effectsForCategory(int? categoryId) {
    if (categoryId == null) return [];
    return List.unmodifiable(_effectsByCategory[categoryId] ?? []);
  }

  Map<String, dynamic>? categoryById(int? id) {
    if (id == null) return null;
    for (final item in _categories) {
      final cid = _asInt(item['id']);
      if (cid == id) return item;
    }
    return null;
  }

  /// 用户自定义音效分类（sound_type = 2）
  int? get customCategoryId {
    for (final item in _categories) {
      final type = _asInt(item['sound_type']);
      final name = item['name']?.toString() ?? '';
      if (type == 2 || name.contains('自定义') || name.contains('录制')) {
        return _asInt(item['id']);
      }
    }
    return _categories.isNotEmpty ? _asInt(_categories.first['id']) : null;
  }

  /// 「我的录制」对应的接口分类（名称、图标等）
  Map<String, dynamic>? get customCategory {
    final id = customCategoryId;
    if (id == null) return null;
    return categoryById(id);
  }

  Future<void> fetchCategories({int? languageId}) async {
    categoriesLoading = true;
    notifyListeners();
    try {
      final query = <String, dynamic>{};
      if (languageId != null) query['language_id'] = languageId;
      final res = await Api.get(ApiPaths.getSoundCategories, query: query);
      _categories
        ..clear()
        ..addAll(_parseList(res.data));
    } on ApiException catch (_) {
    } finally {
      categoriesLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAllEffects({
    int? languageId,
    int page = 1,
    int pageSize = 100,
  }) async {
    allEffectsLoading = true;
    notifyListeners();
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (languageId != null) query['language_id'] = languageId;

      final res = await Api.get(ApiPaths.getSoundEffects, query: query);
      _allEffects = _parsePagedList(res.data).map(_normalizeEffect).toList();
    } on ApiException catch (_) {
    } finally {
      allEffectsLoading = false;
      notifyListeners();
    }
  }

  /// 添加/移除右侧栏音效：has_user_sort=0 传 sort=1，has_user_sort=1 传 sort=0
  Future<({bool ok, String msg})> toggleSidebarEffect(
    Map<String, dynamic> effect,
  ) async {
    if (!canToggleSidebar(effect)) {
      return (ok: false, msg: '');
    }

    final effectId = _asInt(effect['id']);
    if (effectId <= 0) return (ok: false, msg: '');

    final currentHasUserSort = hasUserSortOf(effect);
    final newSort = currentHasUserSort == 0 ? 1 : 0;

    _togglingEffectIds.add(effectId);
    notifyListeners();
    try {
      final result = await setSoundEffectSort(
        effectId: effectId,
        sort: newSort,
      );
      if (result.ok) {
        _patchEffectHasUserSort(effectId, newSort);
      }
      return result;
    } finally {
      _togglingEffectIds.remove(effectId);
      notifyListeners();
    }
  }

  void _patchEffectHasUserSort(int effectId, int hasUserSort) {
    _hasUserSortOverrides[effectId] = hasUserSort;

    void patchList(List<Map<String, dynamic>> list) {
      for (var i = 0; i < list.length; i++) {
        if (_asInt(list[i]['id']) == effectId) {
          list[i] = Map<String, dynamic>.from(list[i])
            ..['has_user_sort'] = hasUserSort;
        }
      }
    }

    patchList(_allEffects);
    for (final entry in _effectsByCategory.entries) {
      patchList(entry.value);
    }
    patchList(_customEffects);
  }

  Future<void> fetchEffects({
    int? categoryId,
    int? languageId,
    int page = 1,
    int pageSize = 50,
    bool replace = true,
  }) async {
    effectsLoading = true;
    notifyListeners();
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (categoryId != null) query['category_id'] = categoryId;
      if (languageId != null) query['language_id'] = languageId;

      final res = await Api.get(ApiPaths.getSoundEffects, query: query);
      final list = _parsePagedList(res.data).map(_normalizeEffect).toList();
      if (categoryId != null) {
        if (replace) {
          _effectsByCategory[categoryId] = list;
        } else {
          final existing = _effectsByCategory[categoryId] ?? [];
          _effectsByCategory[categoryId] = [...existing, ...list];
        }
        _mergeEffectsIntoAll(list);
      }
    } on ApiException catch (_) {
    } finally {
      effectsLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCustomEffects({int? languageId}) async {
    final categoryId = customCategoryId;
    if (categoryId == null) {
      await fetchCategories(languageId: languageId);
    }
    final cid = customCategoryId;
    if (cid == null) return;

    customLoading = true;
    notifyListeners();
    try {
      await fetchEffects(
        categoryId: cid,
        languageId: languageId,
      );
      _customEffects = List<Map<String, dynamic>>.from(
        _effectsByCategory[cid] ?? [],
      );
    } finally {
      customLoading = false;
      notifyListeners();
    }
  }

  Future<({bool ok, String msg, int? effectId})> addCustomSoundEffect({
    required String name,
    required String localPath,
    int? categoryId,
    String? imageUrl,
  }) async {
    final cid = categoryId ?? customCategoryId;
    if (cid == null) {
      return (ok: false, msg: '未找到音效分类', effectId: null);
    }

    try {
      if (kDebugMode) {
        debugPrint(
          '[CameraSoundStore] addCustomSoundEffect: 先上传音频再提交\n'
          '  name: $name\n'
          '  localPath: $localPath\n'
          '  category_id: $cid',
        );
      }
      // 1. 先上传录音文件 → /api/base/upload
      final soundUrl = await FileUploadService.uploadAudio(localPath);
      if (kDebugMode) {
        debugPrint('[CameraSoundStore] 音频上传完成 sound_url: $soundUrl');
      }
      // 2. 再提交自定义音效 → /api/camera/addCustomSoundEffect
      final res = await Api.post(
        ApiPaths.addCustomSoundEffect,
        data: {
          'name': name,
          'sound_url': soundUrl,
          'category_id': cid,
          if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        },
      );
      final effectId = _asInt(
        res.data is Map ? res.data['effect_id'] : null,
      );
      await refreshSidebarEffects();
      return (ok: true, msg: res.msg, effectId: effectId > 0 ? effectId : null);
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('[CameraSoundStore] addCustomSoundEffect failed: $e');
      }
      return (ok: false, msg: e.message, effectId: null);
    }
  }

  Future<({bool ok, String msg})> deleteCustomSoundEffect(int effectId) async {
    try {
      final res = await Api.post(
        ApiPaths.deleteCustomSoundEffect,
        data: {'effect_id': effectId},
      );
      _customEffects.removeWhere((e) => _asInt(e['id']) == effectId);
      _allEffects.removeWhere((e) => _asInt(e['id']) == effectId);
      _hasUserSortOverrides.remove(effectId);
      for (final entry in _effectsByCategory.entries) {
        entry.value.removeWhere((e) => _asInt(e['id']) == effectId);
      }
      notifyListeners();
      return (ok: true, msg: res.msg);
    } on ApiException catch (e) {
      return (ok: false, msg: e.message);
    }
  }

  Future<({bool ok, String msg})> setSoundEffectSort({
    required int effectId,
    required int sort,
  }) async {
    try {
      final res = await Api.post(
        ApiPaths.setSoundEffectSort,
        data: {
          'effect_id': effectId,
          'sort': sort,
        },
      );
      return (ok: true, msg: res.msg);
    } on ApiException catch (e) {
      return (ok: false, msg: e.message);
    }
  }

  void _mergeEffectsIntoAll(List<Map<String, dynamic>> list) {
    for (final effect in list) {
      final id = _asInt(effect['id']);
      if (id <= 0) continue;
      final normalized = _normalizeEffect(effect);
      final index = _allEffects.indexWhere((e) => _asInt(e['id']) == id);
      if (index >= 0) {
        _allEffects[index] = normalized;
      } else {
        _allEffects.add(normalized);
      }
    }
  }

  Map<String, dynamic> _normalizeEffect(Map<String, dynamic> raw) {
    final effect = Map<String, dynamic>.from(raw);
    final id = _asInt(effect['id']);
    final apiHasUserSort = _asInt(effect['has_user_sort']);

    if (_hasUserSortOverrides.containsKey(id)) {
      final override = _hasUserSortOverrides[id]!;
      if (apiHasUserSort == override) {
        _hasUserSortOverrides.remove(id);
        effect['has_user_sort'] = apiHasUserSort;
      } else {
        effect['has_user_sort'] = override;
      }
    }

    return effect;
  }

  static List<Map<String, dynamic>> _parseList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return _parsePagedList(data);
  }

  static List<Map<String, dynamic>> _parsePagedList(dynamic data) {
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
