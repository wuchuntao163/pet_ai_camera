/// 顶部栏闪光灯 UI 状态
enum FlashToolbarState {
  off,
  on,
  auto;

  FlashToolbarState get next {
    switch (this) {
      case off:
        return on;
      case on:
        return auto;
      case auto:
        return off;
    }
  }
}

/// 照片比例选项
class AspectRatioOption {
  final String label;
  final double ratio; // 宽 / 高

  const AspectRatioOption({required this.label, required this.ratio});

  /// 3:4：传感器原生比例，预览 contain（可有黑边），成片直接出图
  bool get usesNativeSensorOutput => label == '3:4';

  /// 仅 9:16 全屏预览（不偏移）
  bool get usesFullScreenPreview => label == '9:16';

  /// 9:16 全屏；3:4 原生无遮罩；1:1 / 4:3 / 16:9 显示取景框遮罩
  bool get usesPreviewMask =>
      !usesNativeSensorOutput && !usesFullScreenPreview;

  /// 默认 3:4
  static const int defaultIndex = 2;

  static const List<AspectRatioOption> all = [
    AspectRatioOption(label: '9:16', ratio: 9 / 16),
    AspectRatioOption(label: '1:1', ratio: 1),
    AspectRatioOption(label: '3:4', ratio: 3 / 4),
    AspectRatioOption(label: '4:3', ratio: 4 / 3),
    AspectRatioOption(label: '16:9', ratio: 16 / 9),
  ];
}

/// 连拍选项
class BurstOption {
  final String title;
  final String? subtitle;
  final int count;

  const BurstOption({required this.title, this.subtitle, required this.count});

  static const List<BurstOption> all = [
    BurstOption(title: '单拍', count: 1),
    BurstOption(title: '3', subtitle: '连拍', count: 3),
    BurstOption(title: '5', subtitle: '连拍', count: 5),
    BurstOption(title: '10', subtitle: '连拍', count: 10),
  ];

  static const int defaultIndex = 0;
}

/// 倒计时选项
class TimerOption {
  final String label;
  final int seconds;

  const TimerOption({required this.label, required this.seconds});

  static const List<TimerOption> all = [
    TimerOption(label: '关闭', seconds: 0),
    TimerOption(label: '3秒', seconds: 3),
    TimerOption(label: '5秒', seconds: 5),
    TimerOption(label: '10秒', seconds: 10),
  ];

  static const int defaultIndex = 0;
}
