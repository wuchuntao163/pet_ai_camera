import 'package:flutter/foundation.dart';

import '../models/camera_config.dart';

/// 相机可配置项，供主界面与设置面板共享
class CameraSettingsStore extends ChangeNotifier {
  int burstIndex = BurstOption.defaultIndex;
  int timerIndex = TimerOption.defaultIndex;
  bool shutterSoundEnabled = true;
  /// 相机右侧宠物音效播放音量（0.0 ~ 1.0）
  double petSoundVolume = 0.8;

  void setBurstIndex(int index) {
    if (index < 0 || index >= BurstOption.all.length) return;
    if (burstIndex == index) return;
    burstIndex = index;
    notifyListeners();
  }

  void setTimerIndex(int index) {
    if (index < 0 || index >= TimerOption.all.length) return;
    if (timerIndex == index) return;
    timerIndex = index;
    notifyListeners();
  }

  void setShutterSoundEnabled(bool enabled) {
    if (shutterSoundEnabled == enabled) return;
    shutterSoundEnabled = enabled;
    notifyListeners();
  }

  void setPetSoundVolume(double value) {
    final v = value.clamp(0.0, 1.0);
    if (petSoundVolume == v) return;
    petSoundVolume = v;
    notifyListeners();
  }
}
