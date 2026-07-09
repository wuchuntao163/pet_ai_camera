import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_colors.dart';
import '../data/app_cache_store.dart';
import '../widgets/toast_message.dart';

/// 版本检查与更新（对齐 uniapp compareVersion + getConfig.app_version）
class AppUpdateUtil {
  AppUpdateUtil._();

  static const _androidPackage = 'com.example.pet_ai_camera';

  static final _cache = AppCacheStore.instance;

  static String? _localVersion;

  static Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    _localVersion = info.version;
    _cache.setLocalVersion(info.version);
  }

  /// 本机安装版本（PackageInfo.version）
  static String get localVersion => _localVersion ?? _cache.localAppVersion;

  /// 服务端最新版本（config.app_version）
  static String? get remoteVersion => _cache.remoteAppVersion;

  static bool get hasNewVersion {
    final remote = remoteVersion;
    if (remote == null || remote.isEmpty) return false;
    return compareVersion(remote, localVersion) > 0;
  }

  /// 与 uniapp compareVersion 一致：v1 > v2 返回 1，小于返回 -1，相等返回 0
  static int compareVersion(String v1, String v2) {
    final p1 = _normalizeVersionParts(v1);
    final p2 = _normalizeVersionParts(v2);
    final len = p1.length > p2.length ? p1.length : p2.length;
    for (var i = 0; i < len; i++) {
      final n1 = i < p1.length ? p1[i] : 0;
      final n2 = i < p2.length ? p2[i] : 0;
      if (n1 > n2) return 1;
      if (n1 < n2) return -1;
    }
    return 0;
  }

  static List<int> _normalizeVersionParts(String raw) {
    final cleaned = raw.split('+').first.trim();
    if (cleaned.isEmpty) return const [0];
    return cleaned
        .split('.')
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList();
  }

  /// 设置页点击「版本号」：有更新弹窗，否则居中提示已是最新
  static Future<void> checkUpdate(BuildContext context) async {
    if (!hasNewVersion) {
      if (!context.mounted) return;
      ToastMessage.show(context, '当前已是最新版本（$localVersion）');
      return;
    }
    await showUpdateDialog(context);
  }

  static Future<void> showUpdateDialog(BuildContext context) async {
    final remote = remoteVersion ?? '';
    final tips = _plainText(_cache.updateTips);

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最新版本：$remote\n当前版本：$localVersion',
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
            if (tips != null) ...[
              const SizedBox(height: 12),
              Text(
                tips,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('稍后'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await openUpdateUrl();
              if (!context.mounted) return;
              if (!ok) {
                ToastMessage.show(context, '暂时无法打开更新链接');
              }
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  /// 打开更新地址（参考 [AppPromotionUtil.openAppStoreRating]）
  static Future<bool> openUpdateUrl() async {
    if (Platform.isIOS) {
      final url = _cache.iosStoreUrl;
      if (!_isHttpUrl(url)) return false;
      return _openUrl(url!);
    }

    if (Platform.isAndroid) {
      final urls = <String>[
        if (_isHttpUrl(_cache.androidStoreUrl)) _cache.androidStoreUrl!,
        if (_isHttpUrl(_cache.shareUrl)) _cache.shareUrl!,
        'market://details?id=$_androidPackage',
        'https://play.google.com/store/apps/details?id=$_androidPackage',
      ];
      for (final url in urls) {
        if (await _openUrl(url)) return true;
      }
    }
    return false;
  }

  static String? _plainText(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  static bool _isHttpUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    final uri = Uri.tryParse(raw.trim());
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  static Future<bool> _openUrl(String raw) async {
    final uri = Uri.tryParse(raw);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
