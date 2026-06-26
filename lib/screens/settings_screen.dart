import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../models/camera_config.dart';
import '../services/camera_settings_store.dart';
import '../widgets/settings_slider_item.dart';
import '../widgets/settings_toggle_item.dart';
import '../widgets/settings_segment_control.dart';

/// 设置面板（底部弹窗）
class SettingsScreen extends StatelessWidget {
  final CameraSettingsStore settings;

  const SettingsScreen({super.key, required this.settings});

  static List<String> get _burstLabels => BurstOption.all
      .map((o) => o.count == 1 ? o.title : '${o.count}张')
      .toList();

  static List<String> get _timerLabels =>
      TimerOption.all.map((o) => o.label).toList();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return Container(
          height:
              MediaQuery.of(context).size.height * AppSizes.settingsSheetHeightFactor,
          decoration: const BoxDecoration(
            color: AppColors.settingsBg,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppSizes.sheetRadius)),
            boxShadow: [
              BoxShadow(
                color: Color(0x40000000),
                offset: Offset(0, -25),
                blurRadius: 50,
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                height: AppSizes.sheetHeaderHeight,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSizes.sheetPaddingH),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/camera/image_18.png',
                            width: 24,
                            height: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '设置',
                            style: TextStyle(
                              fontSize: AppSizes.sheetTitleSize,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: AppSizes.closeBtn,
                          height: AppSizes.closeBtn,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/camera/image_19.png',
                              width: AppSizes.closeIcon,
                              height: AppSizes.closeIcon,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    children: [
                      SettingsSliderItem(
                        iconPath: 'assets/images/camera/image_12.png',
                        title: '音效音量',
                        value: settings.petSoundVolume,
                        onChanged: settings.setPetSoundVolume,
                      ),
                      SettingsToggleItem(
                        icon: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/camera/image_13.png',
                              width: 8.4,
                              height: 10.8,
                            ),
                          ),
                        ),
                        title: '快门声音',
                        subtitle: '拍摄时播放快门音效',
                        value: settings.shutterSoundEnabled,
                        onChanged: settings.setShutterSoundEnabled,
                      ),
                      SettingsSegmentControl(
                        iconPath: 'assets/images/camera/image_15.png',
                        title: '连拍模式',
                        options: _burstLabels,
                        selectedIndex: settings.burstIndex,
                        onChanged: settings.setBurstIndex,
                      ),
                      SettingsSegmentControl(
                        iconPath: 'assets/images/camera/image_16.png',
                        title: '延时拍摄',
                        options: _timerLabels,
                        selectedIndex: settings.timerIndex,
                        onChanged: settings.setTimerIndex,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
