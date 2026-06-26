
/// 预览在屏幕上的实际布局（与 [CameraPreviewView] 一致）
class PreviewScreenLayout {
  final double offsetX;
  final double offsetY;
  final double scaledW;
  final double scaledH;

  const PreviewScreenLayout({
    required this.offsetX,
    required this.offsetY,
    required this.scaledW,
    required this.scaledH,
  });
}

PreviewScreenLayout computePreviewScreenLayout({
  required double screenW,
  required double screenH,
  required double previewAspect,
  required bool fitContain,
  required bool fullScreenPreview,
  required double verticalAlignY,
}) {
  double childW;
  double childH;
  if (screenW / screenH > previewAspect) {
    childH = screenH;
    childW = screenH * previewAspect;
  } else {
    childW = screenW;
    childH = screenW / previewAspect;
  }

  final scaleW = screenW / childW;
  final scaleH = screenH / childH;
  final scale = fitContain
      ? (scaleW < scaleH ? scaleW : scaleH)
      : (scaleW > scaleH ? scaleW : scaleH);
  final scaledW = childW * scale;
  final scaledH = childH * scale;

  final alignY =
      fullScreenPreview ? 0.5 : verticalAlignY.clamp(0.0, 1.0);

  return PreviewScreenLayout(
    offsetX: (screenW - scaledW) / 2,
    offsetY: (screenH - scaledH) * alignY,
    scaledW: scaledW,
    scaledH: scaledH,
  );
}

/// 预览取景框在屏幕上的几何信息（与 [AspectRatioMask] 计算一致）
class PreviewFrameGeometry {
  final double screenWidth;
  final double screenHeight;
  final double boxLeft;
  final double boxTop;
  final double boxWidth;
  final double boxHeight;

  const PreviewFrameGeometry({
    required this.screenWidth,
    required this.screenHeight,
    required this.boxLeft,
    required this.boxTop,
    required this.boxWidth,
    required this.boxHeight,
  });

  /// 计算取景框位置
  static PreviewFrameGeometry compute({
    required double screenWidth,
    required double screenHeight,
    required double ratio,
    double topInset = 0,
    double bottomInset = 0,
    required double frameAlignY,
    bool fullScreen = false,
  }) {
    if (fullScreen || screenWidth <= 0 || screenHeight <= 0) {
      return PreviewFrameGeometry(
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        boxLeft: 0,
        boxTop: 0,
        boxWidth: screenWidth,
        boxHeight: screenHeight,
      );
    }

    final areaTop = topInset;
    final areaH =
        (screenHeight - topInset - bottomInset).clamp(0.0, screenHeight);

    if (areaH <= 0) {
      return PreviewFrameGeometry(
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        boxLeft: 0,
        boxTop: 0,
        boxWidth: screenWidth,
        boxHeight: screenHeight,
      );
    }

    double boxW;
    double boxH;
    if (screenWidth / areaH > ratio) {
      boxH = areaH;
      boxW = areaH * ratio;
    } else {
      boxW = screenWidth;
      boxH = screenWidth / ratio;
    }

    final alignY = frameAlignY.clamp(0.0, 1.0);
    final boxTop =
        (areaTop + (areaH - boxH) * alignY).clamp(0.0, screenHeight - boxH);

    return PreviewFrameGeometry(
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      boxLeft: (screenWidth - boxW) / 2,
      boxTop: boxTop,
      boxWidth: boxW,
      boxHeight: boxH,
    );
  }
}

/// 将屏幕取景框映射到照片像素裁切区域
class ImageCropRect {
  final int x;
  final int y;
  final int width;
  final int height;

  const ImageCropRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

double _previewNormToCaptureNorm(
  double previewNorm,
  double previewAspect,
  double captureAspect,
) {
  if (previewAspect <= 0 || captureAspect <= 0) return previewNorm;
  return 0.5 + (previewNorm - 0.5) * (previewAspect / captureAspect);
}

ImageCropRect mapPreviewFrameToImage({
  required PreviewFrameGeometry frame,
  required double previewAspect,
  required int imageWidth,
  required int imageHeight,
  bool fitContain = false,
  bool fullScreenPreview = false,
  double previewVerticalAlignY = 0.5,
}) {
  final captureAspect = imageWidth / imageHeight;

  final previewLayout = computePreviewScreenLayout(
    screenW: frame.screenWidth,
    screenH: frame.screenHeight,
    previewAspect: previewAspect,
    fitContain: fitContain,
    fullScreenPreview: fullScreenPreview,
    verticalAlignY: previewVerticalAlignY,
  );

  double screenToPreviewNormX(double screenX) {
    return ((screenX - previewLayout.offsetX) / previewLayout.scaledW)
        .clamp(0.0, 1.0);
  }

  double screenToPreviewNormY(double screenY) {
    return ((screenY - previewLayout.offsetY) / previewLayout.scaledH)
        .clamp(0.0, 1.0);
  }

  final px0 = screenToPreviewNormX(frame.boxLeft);
  final py0 = screenToPreviewNormY(frame.boxTop);
  final px1 = screenToPreviewNormX(frame.boxLeft + frame.boxWidth);
  final py1 = screenToPreviewNormY(frame.boxTop + frame.boxHeight);

  var nx0 = _previewNormToCaptureNorm(px0, previewAspect, captureAspect);
  var ny0 = _previewNormToCaptureNorm(py0, previewAspect, captureAspect);
  var nx1 = _previewNormToCaptureNorm(px1, previewAspect, captureAspect);
  var ny1 = _previewNormToCaptureNorm(py1, previewAspect, captureAspect);

  if (nx0 > nx1) {
    final t = nx0;
    nx0 = nx1;
    nx1 = t;
  }
  if (ny0 > ny1) {
    final t = ny0;
    ny0 = ny1;
    ny1 = t;
  }

  nx0 = nx0.clamp(0.0, 1.0);
  ny0 = ny0.clamp(0.0, 1.0);
  nx1 = nx1.clamp(0.0, 1.0);
  ny1 = ny1.clamp(0.0, 1.0);

  if (nx1 <= nx0 || ny1 <= ny0) {
    return centerCropToRatio(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      ratio: frame.boxWidth / frame.boxHeight,
    );
  }

  var x = (nx0 * imageWidth).round();
  var y = (ny0 * imageHeight).round();
  var w = ((nx1 - nx0) * imageWidth).round();
  var h = ((ny1 - ny0) * imageHeight).round();

  if (w <= 0 || h <= 0) {
    return centerCropToRatio(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      ratio: frame.boxWidth / frame.boxHeight,
    );
  }

  if (x + w > imageWidth) w = imageWidth - x;
  if (y + h > imageHeight) h = imageHeight - y;
  x = x.clamp(0, imageWidth - 1);
  y = y.clamp(0, imageHeight - 1);

  return ImageCropRect(
    x: x,
    y: y,
    width: w.clamp(1, imageWidth),
    height: h.clamp(1, imageHeight),
  );
}

ImageCropRect centerCropToRatio({
  required int imageWidth,
  required int imageHeight,
  required double ratio,
}) {
  double cropW;
  double cropH;
  if (imageWidth / imageHeight > ratio) {
    cropH = imageHeight.toDouble();
    cropW = imageHeight * ratio;
  } else {
    cropW = imageWidth.toDouble();
    cropH = imageWidth / ratio;
  }
  final x = ((imageWidth - cropW) / 2).round();
  final y = ((imageHeight - cropH) / 2).round();
  return ImageCropRect(
    x: x,
    y: y,
    width: cropW.round().clamp(1, imageWidth),
    height: cropH.round().clamp(1, imageHeight),
  );
}
