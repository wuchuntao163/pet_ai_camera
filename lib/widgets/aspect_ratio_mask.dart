import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../utils/preview_frame_geometry.dart';

/// 按比例取景：预览居中/靠上裁剪，外围与顶/底栏相同的半透明背景
class AspectRatioMask extends StatelessWidget {
  final double ratio;
  final Widget child;
  final double frameAlignY;

  const AspectRatioMask({
    super.key,
    required this.ratio,
    required this.child,
    this.frameAlignY = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        final frame = PreviewFrameGeometry.compute(
          screenWidth: w,
          screenHeight: h,
          ratio: ratio,
          frameAlignY: frameAlignY,
        );

        if (frame.boxWidth <= 0 || frame.boxHeight <= 0) {
          return ColoredBox(
            color: AppColors.bottomBarBg,
            child: child,
          );
        }

        return ColoredBox(
          color: AppColors.bottomBarBg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: frame.boxLeft,
                top: frame.boxTop,
                width: frame.boxWidth,
                height: frame.boxHeight,
                child: ClipRect(child: child),
              ),
            ],
          ),
        );
      },
    );
  }
}
