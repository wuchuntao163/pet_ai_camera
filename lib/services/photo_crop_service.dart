import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/camera_config.dart';
import '../utils/preview_frame_geometry.dart';

/// 按预览取景框裁切照片，使成片与界面所见一致
class PhotoCropService {
  /// 裁切 [sourcePath] 并覆盖原文件，成功返回路径
  static Future<String?> cropToPreviewFrame({
    required String sourcePath,
    required AspectRatioOption aspectOption,
    required Size screenSize,
    required double previewAspect,
    required double frameAlignY,
    required bool fitContain,
    required bool fullScreenPreview,
    bool mirrorFront = false,
  }) async {
    final params = _CropJobParams(
      sourcePath: sourcePath,
      screenWidth: screenSize.width,
      screenHeight: screenSize.height,
      ratio: fullScreenPreview
          ? screenSize.width / screenSize.height
          : aspectOption.ratio,
      frameAlignY: frameAlignY,
      fullScreen: !aspectOption.usesPreviewMask,
      previewAspect: previewAspect,
      nativeSensorOutput: aspectOption.usesNativeSensorOutput,
      fitContain: fitContain,
      fullScreenPreview: fullScreenPreview,
      mirrorFront: mirrorFront,
    );

    try {
      return compute(_runCropJob, params);
    } catch (_) {
      return null;
    }
  }
}

class _CropJobParams {
  final String sourcePath;
  final double screenWidth;
  final double screenHeight;
  final double ratio;
  final double frameAlignY;
  final bool fullScreen;
  final double previewAspect;
  final bool nativeSensorOutput;
  final bool fitContain;
  final bool fullScreenPreview;
  final bool mirrorFront;

  const _CropJobParams({
    required this.sourcePath,
    required this.screenWidth,
    required this.screenHeight,
    required this.ratio,
    required this.frameAlignY,
    required this.fullScreen,
    required this.previewAspect,
    required this.nativeSensorOutput,
    required this.fitContain,
    required this.fullScreenPreview,
    this.mirrorFront = false,
  });
}

String? _runCropJob(_CropJobParams params) {
  final job = params.nativeSensorOutput ? _cropNativeSensorJob : _cropJob;
  return job(params);
}

img.Image _applyMirrorIfNeeded(img.Image image, bool mirrorFront) {
  return mirrorFront ? img.flipHorizontal(image) : image;
}

/// 传感器原生比例（3:4）：仅校正 EXIF 方向与前置镜像，不裁切
String? _cropNativeSensorJob(_CropJobParams params) {
  try {
    final bytes = File(params.sourcePath).readAsBytesSync();
    var image = img.decodeImage(bytes);
    if (image == null) return null;

    image = img.bakeOrientation(image);
    image = _applyMirrorIfNeeded(image, params.mirrorFront);

    File(params.sourcePath).writeAsBytesSync(
      img.encodeJpg(image, quality: 92),
    );
    return params.sourcePath;
  } catch (_) {
    return null;
  }
}

String? _cropJob(_CropJobParams params) {
  try {
    final bytes = File(params.sourcePath).readAsBytesSync();
    var image = img.decodeImage(bytes);
    if (image == null) return null;

    image = img.bakeOrientation(image);

    final frame = PreviewFrameGeometry.compute(
      screenWidth: params.screenWidth,
      screenHeight: params.screenHeight,
      ratio: params.ratio,
      frameAlignY: params.frameAlignY,
      fullScreen: params.fullScreen,
    );

    final crop = mapPreviewFrameToImage(
      frame: frame,
      previewAspect: params.previewAspect,
      imageWidth: image.width,
      imageHeight: image.height,
      fitContain: params.fitContain,
      fullScreenPreview: params.fullScreenPreview,
      previewVerticalAlignY: params.frameAlignY,
    );

    final cropped = img.copyCrop(
      image,
      x: crop.x,
      y: crop.y,
      width: crop.width,
      height: crop.height,
    );

    final outAspect = cropped.width / cropped.height;
    img.Image output;
    if ((outAspect - params.ratio).abs() > 0.02) {
      final exact = centerCropToRatio(
        imageWidth: cropped.width,
        imageHeight: cropped.height,
        ratio: params.ratio,
      );
      output = img.copyCrop(
        cropped,
        x: exact.x,
        y: exact.y,
        width: exact.width,
        height: exact.height,
      );
    } else {
      output = cropped;
    }

    output = _applyMirrorIfNeeded(output, params.mirrorFront);

    File(params.sourcePath).writeAsBytesSync(
      img.encodeJpg(output, quality: 85),
    );
    return params.sourcePath;
  } catch (_) {
    return null;
  }
}
