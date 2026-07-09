import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

/// 设置面板可点击链接行（推荐、客服、隐私等）
class SettingsLinkItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final bool showArrow;
  final VoidCallback? onTap;

  const SettingsLinkItem({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.showArrow = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        margin: const EdgeInsets.only(bottom: AppSizes.cardGap),
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
            Container(
              width: AppSizes.settingIcon,
              height: AppSizes.settingIcon,
              decoration: const BoxDecoration(
                color: AppColors.petIconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 12, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: AppSizes.bodyFontSize,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (trailing != null) ...[
              Text(
                trailing!,
                style: const TextStyle(
                  fontSize: AppSizes.bodyFontSize,
                  color: AppColors.textGray,
                ),
              ),
              const SizedBox(width: 4),
            ],
            if (showArrow)
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textHint,
              ),
          ],
        ),
      ),
    );
  }
}
