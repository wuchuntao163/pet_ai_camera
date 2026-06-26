import 'package:flutter/foundation.dart';

/// 调试日志（flutter run 终端可见；release 不输出）
void appLog(String message) {
  if (kReleaseMode) return;
  // ignore: avoid_print
  print(message);
}
