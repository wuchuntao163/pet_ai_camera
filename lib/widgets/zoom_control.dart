import 'package:flutter/material.dart';
import '../constants/app_sizes.dart';
import 'pill_segment_bar.dart';

/// 变焦控制器（pill 容器）
class ZoomControl extends StatelessWidget {
  final double currentZoom;
  final double baselineOneX;
  final ValueChanged<double>? onZoomChanged;

  const ZoomControl({
    super.key,
    this.currentZoom = 1.0,
    this.baselineOneX = 1.0,
    this.onZoomChanged,
  });

  static const _uiLabels = ['1X', '2X', '5X'];
  static const _upperLevels = [2.0, 5.0];

  List<double> get _levels => [baselineOneX, ..._upperLevels];

  int get _selectedIndex {
    var bestIndex = 0;
    var bestDiff = (currentZoom - _levels[0]).abs();
    for (var i = 1; i < _levels.length; i++) {
      final diff = (currentZoom - _levels[i]).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  @override
  Widget build(BuildContext context) {
    return PillSegmentBar(
      labels: _uiLabels,
      selectedIndex: _selectedIndex,
      itemHeight: AppSizes.zoomSegmentItemHeight,
      fontSize: AppSizes.zoomFontSize,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.zoomSegmentPaddingH,
        vertical: AppSizes.zoomSegmentPaddingV,
      ),
      onSelected: (index) => onZoomChanged?.call(_levels[index]),
    );
  }
}
