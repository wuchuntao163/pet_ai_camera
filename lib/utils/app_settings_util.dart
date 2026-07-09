import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_cache_store.dart';

/// 设置页：推荐分享、联系客服、隐私政策
///
/// 链接字段来自 getConfig 返回的 config：
/// share_url、day_customer_service_link、privacy_url（可选）
class AppSettingsUtil {
  AppSettingsUtil._();

  static final _cache = AppCacheStore.instance;

  static String get _appName => _cache.displayAppName;

  static String get _shareText {
    final link = _cache.shareUrl;
    final intro = '推荐一款宠物拍照 App「$_appName」，记录毛孩子的每一个美好瞬间～';
    return link != null ? '$intro\n$link' : intro;
  }

  static Future<void> shareRecommend({Rect? sharePositionOrigin}) async {
    await Share.share(
      _shareText,
      subject: _appName,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  static Future<bool> openCustomerService() async {
    final url = _cache.customerServiceLink;
    if (url == null) return false;
    return _openUrl(url);
  }

  static Future<bool> openPrivacyPolicy() async {
    return _openUrl(_cache.privacyPolicyUrl);
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
