import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// 顶部工具选项弹窗（照片比例 / 连拍 / 倒计时）
class CameraToolPopup extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final Widget child;

  const CameraToolPopup({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
        decoration: BoxDecoration(
          color: AppColors.settingsBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              offset: Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/camera/image_19.png',
                        width: 10,
                        height: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderCard),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// 弹窗内选项卡片（选中橙色边框）
class CameraPopupOption extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  const CameraPopupOption({
    super.key,
    required this.isSelected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 88,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.tabSelectedBg : AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderCard,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// 比例示意矩形
class AspectRatioPreviewIcon extends StatelessWidget {
  final double ratio;
  final bool isSelected;

  const AspectRatioPreviewIcon({
    super.key,
    required this.ratio,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    const maxW = 28.0;
    const maxH = 36.0;
    late double w, h;
    if (ratio >= 1) {
      w = maxW;
      h = maxW / ratio;
    } else {
      h = maxH;
      w = maxH * ratio;
    }

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: isSelected ? AppColors.primary : const Color(0xFFD1D5DB),
        ),
      ),
    );
  }
}
