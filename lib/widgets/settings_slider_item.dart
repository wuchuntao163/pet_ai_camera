import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

/// 设置面板滑块项
class SettingsSliderItem extends StatelessWidget {
  final String iconPath;
  final String title;
  final double value;
  final ValueChanged<double>? onChanged;

  const SettingsSliderItem({
    super.key,
    required this.iconPath,
    required this.title,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return Container(
      height: 54,
      margin: const EdgeInsets.only(bottom: AppSizes.cardGap),
      padding: const EdgeInsets.only(left: 17),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: AppColors.borderCard),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Row(
              children: [
                Image.asset(iconPath, width: 18, height: 15),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppSizes.bodyFontSize,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.divider,
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withValues(alpha: 0.2),
                ),
                child: Slider(value: value, onChanged: onChanged),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$percent%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: AppSizes.bodyFontSize,
                fontWeight: FontWeight.w500,
                color: AppColors.textGray,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
