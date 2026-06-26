import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../native_camera/native_camera_preview.dart';
import '../utils/preview_frame_geometry.dart';

/// 相机预览
class CameraPreviewView extends StatelessWidget {
  /// 传感器流宽高比（宽/高，竖屏通常约 3:4 = 0.75）
  final double previewAspectRatio;

  /// true = contain 完整显示传感器（可有黑边，接近系统相机 3:4）
  final bool fitContain;

  /// true = 全屏预览（原生 ViewPort 铺满整屏）
  final bool fullScreen;

  /// 垂直位置：0=顶，0.5=居中，1=底（遮罩/非全屏模式）
  final double verticalAlignY;

  const CameraPreviewView({
    super.key,
    required this.previewAspectRatio,
    this.fitContain = false,
    this.fullScreen = false,
    this.verticalAlignY = AppSizes.previewVerticalAlignY,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewW = constraints.maxWidth;
        final viewH = constraints.maxHeight;

        if (fullScreen) {
          // 9:16 全屏：原生 ViewPort 裁切，预览铺满整屏
          return const SizedBox.expand(
            child: NativeCameraPreview(),
          );
        }

        final layout = computePreviewScreenLayout(
          screenW: viewW,
          screenH: viewH,
          previewAspect: previewAspectRatio,
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
