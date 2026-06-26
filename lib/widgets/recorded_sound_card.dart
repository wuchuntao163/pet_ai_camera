import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../constants/app_sizes.dart';
import '../models/recorded_sound.dart';

/// 我的录制音效卡片（统一麦克风图标，支持删除）
class RecordedSoundCard extends StatelessWidget {
  final RecordedSound sound;
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const RecordedSoundCard({
    super.key,
    required this.sound,
    this.isPlaying = false,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.soundCardHeight,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.soundCardRadius),
        border: Border.all(color: AppColors.borderCard),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.petIconBg,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Center(
                      child: Image.asset(
                        AppImages.micIcon,
                        width: 18,
                        height: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      sound.name,
                      style: const TextStyle(
                        fontSize: AppSizes.soundCardTitleSize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.soundCardTitle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Icon(
                isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                size: AppSizes.soundCardActionIcon,
                color: AppColors.notePurple,
              ),
            ),
          ),
          if (onDelete != null)
            GestureDetector(
              onTap: onDelete,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSizes.soundCardActionGap),
                child: Icon(
                  Icons.delete_outline,
                  size: AppSizes.soundCardActionIcon,
                  color: AppColors.textGray,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
