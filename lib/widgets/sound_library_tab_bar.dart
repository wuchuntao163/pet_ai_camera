import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

/// 音效库 Tab（我的录制 + 接口分类）
class SoundLibraryTab {
  final String label;
  final String? emoji;
  final String? iconUrl;
  final int? categoryId;
  final bool isRecordings;

  const SoundLibraryTab({
    required this.label,
    this.emoji,
    this.iconUrl,
    this.categoryId,
    this.isRecordings = false,
  });
}

class SoundLibraryTabBar extends StatelessWidget {
  final List<SoundLibraryTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  const SoundLibraryTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  Color _activeBg(SoundLibraryTab tab) => AppColors.primary;

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: AppSizes.soundTabHeight + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        itemCount: tabs.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onTabChanged(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _activeBg(tab) : AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : AppColors.tabInactiveBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TabIcon(tab: tab),
                  const SizedBox(width: 4),
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: AppSizes.soundTabFontSize,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.tabTextActive
                          : AppColors.tabTextInactive,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TabIcon extends StatelessWidget {
  final SoundLibraryTab tab;

  const _TabIcon({required this.tab});

  @override
  Widget build(BuildContext context) {
    final iconUrl = tab.iconUrl;
    if (iconUrl != null && iconUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          iconUrl,
          width: AppSizes.soundTabEmojiSize + 2,
          height: AppSizes.soundTabEmojiSize + 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _emojiFallback(),
        ),
      );
    }
    return _emojiFallback();
  }

  Widget _emojiFallback() {
    return Text(
      tab.emoji ?? '🔊',
      style: const TextStyle(fontSize: AppSizes.soundTabEmojiSize),
    );
  }
}
