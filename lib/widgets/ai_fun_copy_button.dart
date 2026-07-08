import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_images.dart';

/// 相册大图页底部操作：调色盘 + 它想说
class PhotoViewerBottomActions extends StatelessWidget {
  final VoidCallback? onPalette;
  final VoidCallback? onWantToSay;

  const PhotoViewerBottomActions({
    super.key,
    this.onPalette,
    this.onWantToSay,
  });

  static const _buttonColor = AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ActionButton(
            iconAsset: AppImages.microphone,
            label: '调色盘',
            backgroundColor: AppColors.paletteActionBg,
            onTap: onPalette,
          ),
          const SizedBox(width: 20),
          _ActionButton(
            iconAsset: AppImages.wantToSay,
            label: '它想说',
            backgroundColor: AppColors.paletteActionBg,
            onTap: onWantToSay,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String iconAsset;
  final String label;
  final Color backgroundColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.iconAsset,
    required this.label,
    this.backgroundColor = PhotoViewerBottomActions._buttonColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ButtonIcon(asset: iconAsset),
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonIcon extends StatelessWidget {
  final String asset;

  const _ButtonIcon({required this.asset});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Image.asset(
        asset,
        width: 22,
        height: 22,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.image_outlined,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }
}
