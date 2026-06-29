import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../native_camera/native_camera_preview.dart';
import '../utils/preview_frame_geometry.dart';

/// 相机预览（PlatformView 常驻全屏，遮罩用叠层实现，避免切换比例时销毁原生视图）
class CameraPreviewView extends StatelessWidget {
  /// 非 null 时用遮罩条标出取景框（1:1 / 4:3 / 16:9）
  final double? maskRatio;

  /// 垂直位置：0=顶，0.5=居中，1=底（遮罩模式）
  final double verticalAlignY;

  const CameraPreviewView({
    super.key,
    this.maskRatio,
    this.verticalAlignY = AppSizes.previewVerticalAlignY,
  });

  static const _platformViewKey = ValueKey<String>('native_camera_preview');

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bottomBarBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const SizedBox.expand(
            child: NativeCameraPreview(key: _platformViewKey),
          ),
          if (maskRatio != null)
            _PreviewMaskOverlay(
              ratio: maskRatio!,
              frameAlignY: verticalAlignY,
            ),
        ],
      ),
    );
  }
}

/// 取景遮罩：在 PlatformView 上叠黑条，避免 ClipRect 触发原生视图重建
class _PreviewMaskOverlay extends StatelessWidget {
  final double ratio;
  final double frameAlignY;

  const _PreviewMaskOverlay({
    required this.ratio,
    required this.frameAlignY,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frame = PreviewFrameGeometry.compute(
          screenWidth: constraints.maxWidth,
          screenHeight: constraints.maxHeight,
          ratio: ratio,
          frameAlignY: frameAlignY,
        );

        if (frame.boxWidth <= 0 || frame.boxHeight <= 0) {
          return const SizedBox.shrink();
        }

        final maskColor = AppColors.bottomBarBg;
        final bottom =
            constraints.maxHeight - frame.boxTop - frame.boxHeight;
        final right =
            constraints.maxWidth - frame.boxLeft - frame.boxWidth;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (frame.boxTop > 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: frame.boxTop,
                child: ColoredBox(color: maskColor),
              ),
            if (bottom > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: bottom,
                child: ColoredBox(color: maskColor),
              ),
            if (frame.boxLeft > 0)
              Positioned(
                top: frame.boxTop,
                left: 0,
                width: frame.boxLeft,
                height: frame.boxHeight,
                child: ColoredBox(color: maskColor),
              ),
            if (right > 0)
              Positioned(
                top: frame.boxTop,
                right: 0,
                width: right,
                height: frame.boxHeight,
                child: ColoredBox(color: maskColor),
              ),
          ],
        );
      },
    );
  }
}
