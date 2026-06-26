import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/camera_config.dart';
import 'camera_tool_popup.dart';

class AspectRatioPopup extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onClose;

  const AspectRatioPopup({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return CameraToolPopup(
      title: '照片比例',
      onClose: onClose,
      child: Row(
        children: List.generate(AspectRatioOption.all.length, (index) {
          final option = AspectRatioOption.all[index];
          final isSelected = index == selectedIndex;
          return CameraPopupOption(
            isSelected: isSelected,
            onTap: () {
              onSelected(index);
              onClose();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatioPreviewIcon(
                  ratio: option.ratio,
                  isSelected: isSelected,
                ),
                const SizedBox(height: 8),
                Text(
                  option.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class BurstModePopup extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onClose;

  const BurstModePopup({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return CameraToolPopup(
      title: '连拍模式',
      onClose: onClose,
      child: Row(
        children: List.generate(BurstOption.all.length, (index) {
          final option = BurstOption.all[index];
          final isSelected = index == selectedIndex;
          return CameraPopupOption(
            isSelected: isSelected,
            onTap: () {
              onSelected(index);
              onClose();
            },
            child: option.subtitle == null
                ? Text(
                    option.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        option.subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? AppColors.primary : AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
          );
        }),
      ),
    );
  }
}

class TimerPopup extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onClose;

  const TimerPopup({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return CameraToolPopup(
      title: '拍照倒计时',
      onClose: onClose,
      child: Row(
        children: List.generate(TimerOption.all.length, (index) {
          final option = TimerOption.all[index];
          final isSelected = index == selectedIndex;
          return CameraPopupOption(
            isSelected: isSelected,
            onTap: () {
              onSelected(index);
              onClose();
            },
            child: Text(
              option.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          );
        }),
      ),
    );
  }
}
