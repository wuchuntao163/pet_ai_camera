import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../constants/app_sizes.dart';
import 'translucent_circle_button.dart';

/// 相机顶部工具栏：设置 | 比例 | 连拍 | 定时 | 闪光灯
class CameraTopBar extends StatelessWidget {
  final String aspectRatioLabel;
  final String flashIconPath;
  final VoidCallback? onSettings;
  final VoidCallback? onAspectRatio;
  final VoidCallback? onBurst;
  final VoidCallback? onTimer;
  final VoidCallback? onFlash;
  final String? burstBadge;
  final String? timerBadge;

  const CameraTopBar({
    super.key,
    this.aspectRatioLabel = '3:4',
    this.flashIconPath = AppImages.flashOff,
    this.onSettings,
    this.onAspectRatio,
    this.onBurst,
    this.onTimer,
    this.onFlash,
    this.burstBadge,
    this.timerBadge,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.topBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TranslucentCircleButton(
              size: AppSizes.toolbarBtn,
              onTap: onSettings,
              child: Image.asset(
                AppImages.settingsIcon,
                width: AppSizes.toolbarSettingsIcon,
                height: AppSizes.toolbarSettingsIcon,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(
              height: AppSizes.toolbarBtn,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _AspectRatioButton(
                    label: aspectRatioLabel,
                    onTap: onAspectRatio,
                  ),
                  SizedBox(width: AppSizes.toolbarGap),
                  _ToolbarIconWithBadge(
                    badge: burstBadge,
                    child: TranslucentCircleButton(
                      size: AppSizes.toolbarBtn,
                      onTap: onBurst,
                      child: Image.asset(
                        AppImages.burstMode,
                        width: AppSizes.toolbarBurstIcon,
                        height: AppSizes.toolbarBurstIcon,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(width: AppSizes.toolbarGap),
                  _ToolbarIconWithBadge(
                    badge: timerBadge,
                    child: TranslucentCircleButton(
                      size: AppSizes.toolbarBtn,
                      onTap: onTimer,
                      child: Image.asset(
                        AppImages.timer,
                        width: AppSizes.toolbarTimerIcon,
                        height: AppSizes.toolbarTimerIcon,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(width: AppSizes.toolbarGap),
                  TranslucentCircleButton(
                    size: AppSizes.toolbarBtn,
                    onTap: onFlash,
                    child: Image.asset(
                      flashIconPath,
                      width: AppSizes.toolbarFlashIcon,
                      height: AppSizes.toolbarFlashIcon,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarIconWithBadge extends StatelessWidget {
  final String? badge;
  final Widget child;

  const _ToolbarIconWithBadge({
    required this.badge,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (badge == null || badge!.isEmpty) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              badge!,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.textOnDark,
                height: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AspectRatioButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _AspectRatioButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48,
        height: AppSizes.toolbarBtn,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.translucentBtn,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: AppSizes.aspectRatioFontSize,
            fontWeight: FontWeight.bold,
            color: AppColors.textOnDark,
            height: 1,
          ),
        ),
      ),
    );
  }
}
