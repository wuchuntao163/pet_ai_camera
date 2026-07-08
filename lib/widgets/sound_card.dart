import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../constants/app_sizes.dart';

/// 音效列表卡片
class SoundCard extends StatelessWidget {
  final String emoji;
  final String name;
  final String? imageUrl;
  final String? leadingAsset;
  final bool isAdded;
  final bool isPlaying;
  final bool isToggling;
  final VoidCallback? onPlayPause;
  final VoidCallback? onToggleAdd;
  final VoidCallback? onDelete;

  const SoundCard({
    super.key,
    required this.emoji,
    required this.name,
    this.imageUrl,
    this.leadingAsset,
    this.isAdded = false,
    this.isPlaying = false,
    this.isToggling = false,
    this.onPlayPause,
    this.onToggleAdd,
    this.onDelete,
  });

  static const _actionIconSize = AppSizes.soundCardActionIcon;

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
              onTap: onPlayPause,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  _buildLeading(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
          _buildPlayPauseButton(),
          if (onToggleAdd != null) _buildAddButton(),
          if (onDelete != null) _buildDeleteButton(),
        ],
      ),
    );
  }

  Widget _buildDeleteButton() {
    return GestureDetector(
      onTap: onDelete,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSizes.soundCardActionGap),
        child: Image.asset(
          AppImages.delete,
          width: AppSizes.soundCardAssetActionIcon,
          height: AppSizes.soundCardAssetActionIcon,
          fit: BoxFit.contain,
          color: AppColors.textGray,
          colorBlendMode: BlendMode.srcIn,
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton() {
    return GestureDetector(
      onTap: onPlayPause,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Icon(
          isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
          size: _actionIconSize,
          color: AppColors.notePurple,
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    if (isToggling) {
      return Padding(
        padding: const EdgeInsets.only(left: AppSizes.soundCardActionGap),
        child: SizedBox(
          width: _actionIconSize,
          height: _actionIconSize,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return GestureDetector(
      onTap: onToggleAdd,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSizes.soundCardActionGap),
        child: Icon(
          isAdded ? Icons.check_circle : Icons.add_circle_outline,
          size: _actionIconSize,
          color: isAdded ? AppColors.freeTagGreen : AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildLeading() {
    final asset = leadingAsset;
    if (asset != null && asset.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          asset,
          width: AppSizes.soundCardEmoji,
          height: AppSizes.soundCardEmoji,
          fit: BoxFit.cover,
        ),
      );
    }

    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: AppSizes.soundCardEmoji,
          height: AppSizes.soundCardEmoji,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _emojiText(),
        ),
      );
    }
    return _emojiText();
  }

  Widget _emojiText() {
    return Text(
      emoji,
      style: const TextStyle(fontSize: AppSizes.soundCardEmoji),
    );
  }
}
