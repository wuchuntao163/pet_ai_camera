import 'dart:io';

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../constants/app_sizes.dart';
import 'pill_segment_bar.dart';
import 'translucent_circle_button.dart';

/// 相机底部栏
class CameraBottomBar extends StatelessWidget {
  final bool isPhotoMode;
  final VoidCallback? onShutter;
  final VoidCallback? onGallery;
  final VoidCallback? onFlipCamera;
  final ValueChanged<bool>? onModeChanged;
  final String? galleryThumbLocalPath;
  final String? galleryThumbRemoteUrl;
  final bool galleryThumbPreferCloud;
  final int lastPhotoRevision;
  final bool isGalleryLoading;
  final bool transparentBackground;

  const CameraBottomBar({
    super.key,
    this.isPhotoMode = true,
    this.onShutter,
    this.onGallery,
    this.onFlipCamera,
    this.onModeChanged,
    this.galleryThumbLocalPath,
    this.galleryThumbRemoteUrl,
    this.galleryThumbPreferCloud = false,
    this.lastPhotoRevision = 0,
    this.isGalleryLoading = false,
    this.transparentBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: transparentBackground ? Colors.transparent : AppColors.bottomBarBg,
      padding: const EdgeInsets.only(left: 32, right: 32, bottom: 48, top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: Offset(
              0,
              Platform.isIOS
                  ? AppSizes.iosModeSegmentShiftDown
                  : -AppSizes.modeSegmentShiftUp,
            ),
            child: PillSegmentBar(
              labels: const ['照片', ''],
              selectedIndex: isPhotoMode ? 0 : 1,
              showOuterTrack: false,
              itemWidth: 56,
              itemHeight: AppSizes.zoomSegmentItemHeight,
              fontSize: AppSizes.modeSegmentFontSize,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.zoomSegmentPaddingH,
                vertical: AppSizes.zoomSegmentPaddingV,
              ),
              onSelected: (index) => onModeChanged?.call(index == 0),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _GalleryButton(
                localPath: galleryThumbLocalPath,
                remoteUrl: galleryThumbRemoteUrl,
                preferCloud: galleryThumbPreferCloud,
                revision: lastPhotoRevision,
                isLoading: isGalleryLoading,
                onTap: isGalleryLoading ? null : onGallery,
              ),
              GestureDetector(
                onTap: onShutter,
                child: Container(
                  width: AppSizes.shutterOuter,
                  height: AppSizes.shutterOuter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.textOnDark,
                      width: AppSizes.shutterBorder,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: AppSizes.shutterInner,
                      height: AppSizes.shutterInner,
                      decoration: const BoxDecoration(
                        color: AppColors.textOnDark,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
              TranslucentCircleButton(
                size: AppSizes.flipBtn,
                onTap: onFlipCamera,
                child: Image.asset(
                  AppImages.flipCamera,
                  width: 26,
                  height: 26,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 左下角相册缩略图
class _GalleryButton extends StatelessWidget {
  final String? localPath;
  final String? remoteUrl;
  final bool preferCloud;
  final int revision;
  final bool isLoading;
  final VoidCallback? onTap;

  const _GalleryButton({
    this.localPath,
    this.remoteUrl,
    this.preferCloud = false,
    this.revision = 0,
    this.isLoading = false,
    this.onTap,
  });

  static const _thumbRadius = 6.0;

  @override
  Widget build(BuildContext context) {
    final size = AppSizes.galleryThumb;
    final cacheSize =
        (size * MediaQuery.devicePixelRatioOf(context)).round().clamp(48, 96);

    final showLocal = !preferCloud && localPath != null && localPath!.isNotEmpty;
    final showRemote = preferCloud && remoteUrl != null && remoteUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.translucentBtn,
          borderRadius: BorderRadius.circular(_thumbRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showLocal)
              Image.file(
                File(localPath!),
                key: ValueKey('local-$localPath-$revision'),
                width: size,
                height: size,
                cacheWidth: cacheSize,
                cacheHeight: cacheSize,
                gaplessPlayback: true,
                fit: BoxFit.cover,
              )
            else if (showRemote)
              Image.network(
                remoteUrl!,
                key: ValueKey('remote-$remoteUrl-$revision'),
                width: size,
                height: size,
                cacheWidth: cacheSize,
                cacheHeight: cacheSize,
                gaplessPlayback: true,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _placeholder(),
              )
            else if (localPath != null && localPath!.isNotEmpty)
              Image.file(
                File(localPath!),
                key: ValueKey('local-fallback-$localPath-$revision'),
                width: size,
                height: size,
                cacheWidth: cacheSize,
                cacheHeight: cacheSize,
                gaplessPlayback: true,
                fit: BoxFit.cover,
              )
            else
              _placeholder(),
            if (isLoading) _loadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Image.asset(
        AppImages.galleryThumb,
        width: 28,
        height: 28,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _loadingOverlay() {
    return Container(
      color: const Color(0x99000000),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.textOnDark,
          ),
        ),
      ),
    );
  }
}
