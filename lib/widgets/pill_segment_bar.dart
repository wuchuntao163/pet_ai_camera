import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// 与变焦条一致的 pill 分段选择器（1X / 2X 同款样式）
class PillSegmentBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;
  final double itemWidth;
  final double itemHeight;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  /// 为 false 时不绘制最外层 pill 轨道（如无视频时仅保留「照片」内层选中样式）
  final bool showOuterTrack;

  const PillSegmentBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    this.onSelected,
    this.itemWidth = 48,
    this.itemHeight = 32,
    this.fontSize = 11,
    this.padding = const EdgeInsets.all(4),
    this.showOuterTrack = true,
  });

  static const _slotMarginH = 2.0;

  double get _trackWidth =>
      labels.length * itemWidth + labels.length * _slotMarginH * 2;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: AppColors.translucentBtn,
      borderRadius: BorderRadius.circular(20),
    );

    final visibleIndices = <int>[
      for (var i = 0; i < labels.length; i++)
        if (labels[i].isNotEmpty) i,
    ];

    final slots = [
      for (var index = 0; index < labels.length; index++)
        _slot(
          index: index,
          isSelected: index == selectedIndex,
        ),
    ];

    Widget track;
    if (visibleIndices.length == 1) {
      final index = visibleIndices.first;
      final isSelected = index == selectedIndex;
      track = SizedBox(
        width: _trackWidth,
        child: Center(child: _slot(index: index, isSelected: isSelected)),
      );
    } else {
      track = Row(
        mainAxisSize: MainAxisSize.min,
        children: slots,
      );
    }

    if (!showOuterTrack) return track;

    return Container(
      padding: padding,
      decoration: decoration,
      child: track,
    );
  }

  Widget _slot({required int index, required bool isSelected}) {
    final label = labels[index];
    final enabled = label.isNotEmpty;
    return GestureDetector(
      onTap: enabled ? () => onSelected?.call(index) : null,
      child: Container(
        width: itemWidth,
        height: itemHeight,
        margin: const EdgeInsets.symmetric(horizontal: _slotMarginH),
        decoration: BoxDecoration(
          color: isSelected && enabled
              ? AppColors.bottomTranslucentBtn
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: enabled
              ? Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? AppColors.textOnDark
                        : AppColors.textLight,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
