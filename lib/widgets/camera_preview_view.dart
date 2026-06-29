import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../native_camera/native_camera_preview.dart';
import '../utils/preview_frame_geometry.dart';

/// 相机预览
///
/// - iOS：PlatformView 常驻全屏，遮罩用叠层（避免切换比例时销毁原生视图）
/// - Android：按传感器比例 contain/铺满定位预览（3:4 上下留黑边）
class CameraPreviewView extends StatelessWidget {
  /// iOS 遮罩模式：非 null 时用黑条标出取景框（1:1 / 4:3 / 16:9）
  final double? maskRatio;

  /// Android 定位模式：传感器流宽高比（宽/高）
  final double? previewAspectRatio;

  /// Android：true = contain 完整显示传感器（3:4 可有黑边）
  final bool fitContain;

  /// Android：true = 全屏预览（9:16 原生 ViewPort 铺满）
  final bool fullScreen;

  /// true = Android 定位布局；false = iOS 全屏叠层布局
  final bool usePositionedLayout;

  /// 垂直位置：0=顶，0.5=居中，1=底
  final double verticalAlignY;

  const CameraPreviewView({
    super.key,
    this.maskRatio,
    this.previewAspectRatio,
    this.fitContain = false,
    this.fullScreen = false,
    this.usePositionedLayout = false,
    this.verticalAlignY = AppSizes.previewVerticalAlignY,
  });

  static const _platformViewKey = ValueKey<String>('native_camera_preview');

  @override
  Widget build(BuildContext context) {
    if (usePositionedLayout) {
      return _buildPositionedLayout();
    }
    return _buildOverlayLayout();
  }

  Widget _buildOverlayLayout() {
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

  Widget _buildPositionedLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewW = constraints.maxWidth;
        final viewH = constraints.maxHeight;

        if (fullScreen) {
          return const SizedBox.expand(
            child: NativeCameraPreview(),
          );
        }

        final aspect = previewAspectRatio ?? (3 / 4);
        final layout = computePreviewScreenLayout(
          screenW: viewW,
          screenH: viewH,
          previewAspect: aspect,
          fitContain: fitContain,
          fullScreenPreview: false,
          verticalAlignY: verticalAlignY,
        );

        return ColoredBox(
          color: AppColors.bottomBarBg,
          child: Stack(
            children: [
              Positioned(
                left: layout.offsetX,
                top: layout.offsetY,
                width: layout.scaledW,
                height: layout.scaledH,
                child: const NativeCameraPreview(),
              ),
            ],
          ),
        );
      },
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
