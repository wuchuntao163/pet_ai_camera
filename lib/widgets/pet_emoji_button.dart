import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../constants/app_sizes.dart';
import '../models/sidebar_sound_slot.dart';

/// 右侧栏菜单项标签（最多 5 个字）
String petMenuLabel(String name) {
  if (name.length <= 5) return name;
  return name.substring(0, 5);
}

/// 右侧栏圆形按钮（内容在圆内）
class PetSidebarMenuItem extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double size;

  const PetSidebarMenuItem({
    super.key,
    required this.child,
    this.onTap,
    this.size = AppSizes.petMenuBtn,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppColors.translucentBtn,
          shape: BoxShape.circle,
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// 圆内名称：一行最多 5 字，自动缩放不超出圆形
Widget _petMenuCircleLabel(String name) {
  return Transform.translate(
    offset: const Offset(0, -AppSizes.petMenuCircleTextShiftUp),
    child: SizedBox(
      width: AppSizes.petMenuTextMaxWidth,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          petMenuLabel(name),
          maxLines: 1,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: AppSizes.petMenuCircleFontSize,
            fontWeight: FontWeight.w500,
            color: AppColors.textOnDark,
            height: 1.0,
          ),
        ),
      ),
    ),
  );
}

/// 右侧宠物菜单（可滚动音效列表 + 更多音效 + 收起/提醒）
class PetEmojiMenu extends StatefulWidget {
  final List<SidebarSoundSlot> slots;
  final ValueChanged<int>? onTap;
  final VoidCallback? onMoreSounds;

  const PetEmojiMenu({
    super.key,
    required this.slots,
    this.onTap,
    this.onMoreSounds,
  });

  @override
  State<PetEmojiMenu> createState() => _PetEmojiMenuState();
}

class _PetEmojiMenuState extends State<PetEmojiMenu> {
  bool _expanded = true;

  Widget _collapseButton({required VoidCallback onTap}) {
    return PetSidebarMenuItem(
      size: AppSizes.petMenuToggleBtn,
      onTap: onTap,
      child: Image.asset(
        AppImages.petSidebarCollapse,
        width: AppSizes.petMenuCollapseIcon,
        height: AppSizes.petMenuCollapseIcon,
        color: AppColors.textOnDark.withValues(alpha: 0.85),
        colorBlendMode: BlendMode.srcIn,
      ),
    );
  }

  Widget _moreSoundsButton() {
    return PetSidebarMenuItem(
      onTap: widget.onMoreSounds,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            AppImages.petSidebarMore,
            width: AppSizes.petMenuMoreIcon,
            height: AppSizes.petMenuMoreIcon,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: AppSizes.petMenuCircleContentGap),
          _petMenuCircleLabel('更多音效'),
        ],
      ),
    );
  }

  Widget _slotIcon(SidebarSoundSlot slot) {
    final asset = slot.leadingAsset;
    if (asset != null && asset.isNotEmpty) {
      return Image.asset(
        asset,
        width: AppSizes.petMenuEmoji + 4,
        height: AppSizes.petMenuEmoji + 4,
        fit: BoxFit.contain,
      );
    }
    final imageUrl = slot.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: AppSizes.petMenuEmoji + 4,
          height: AppSizes.petMenuEmoji + 4,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Text(
            slot.emoji,
            style: const TextStyle(fontSize: AppSizes.petMenuEmoji),
          ),
        ),
      );
    }
    return Text(
      slot.emoji,
      style: const TextStyle(fontSize: AppSizes.petMenuEmoji),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return PetSidebarMenuItem(
        size: AppSizes.petMenuToggleBtn,
        onTap: () => setState(() => _expanded = true),
        child: Image.asset(
          AppImages.petSidebarRemind,
          width: AppSizes.petMenuRemindIcon,
          height: AppSizes.petMenuRemindIcon,
          fit: BoxFit.contain,
        ),
      );
    }

    final hasMoreSounds = widget.onMoreSounds != null;
    final listItemCount = widget.slots.length + (hasMoreSounds ? 1 : 0);

    return SizedBox(
      height: AppSizes.petMenuScrollHeight,
      width: AppSizes.petMenuBtn,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.petMenuScrollHeight,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < listItemCount; index++) ...[
                if (index > 0) const SizedBox(height: AppSizes.petMenuItemGap),
                _buildListItem(index, hasMoreSounds),
              ],
              if (listItemCount > 0)
                const SizedBox(height: AppSizes.petMenuItemGap),
              _collapseButton(onTap: () => setState(() => _expanded = false)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListItem(int index, bool hasMoreSounds) {
    if (hasMoreSounds && index == widget.slots.length) {
      return _moreSoundsButton();
    }
    final slot = widget.slots[index];
    return PetSidebarMenuItem(
      onTap: () => widget.onTap?.call(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _slotIcon(slot),
          const SizedBox(height: AppSizes.petMenuCircleContentGap),
          _petMenuCircleLabel(slot.name),
        ],
      ),
    );
  }
}
