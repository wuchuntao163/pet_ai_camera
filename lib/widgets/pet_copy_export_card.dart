import 'package:flutter/material.dart';

import '../services/pet_text_service.dart';
import 'export_card_center_image.dart';
import 'organic_bubble.dart';

/// AI 趣味文案导出卡片（相框：内边距 + 原图完整显示 + 底色文案区）
class PetCopyExportCard extends StatefulWidget {
  final String? localPath;
  final String? remoteUrl;
  final String text;
  final Color textBackgroundColor;
  final Color textColor;
  final int bubbleSeed;
  final double width;
  final bool roundCorners;
  final VoidCallback? onImageReady;

  const PetCopyExportCard({
    super.key,
    this.localPath,
    this.remoteUrl,
    required this.text,
    required this.textBackgroundColor,
    this.textColor = kPetCopyTextColor,
    this.bubbleSeed = 0,
    required this.width,
    this.roundCorners = true,
    this.onImageReady,
  });

  @override
  State<PetCopyExportCard> createState() => _PetCopyExportCardState();
}

class _PetCopyExportCardState extends State<PetCopyExportCard> {
  static const _frameInset = 16.0;
  static const _textInsetVertical = 30.0;
  static const _textInsetHorizontal = 16.0;
  static const _fallbackAspectRatio = 3 / 4;

  double? _imageAspectRatio;

  @override
  void didUpdateWidget(covariant PetCopyExportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localPath != widget.localPath ||
        oldWidget.remoteUrl != widget.remoteUrl) {
      _imageAspectRatio = null;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onAspectRatioResolved(double ratio) {
    if (!mounted || ratio <= 0) return;
    if (_imageAspectRatio == ratio) return;
    setState(() => _imageAspectRatio = ratio);
  }

  void _onImageDisplayed() {
    widget.onImageReady?.call();
  }

  @override
  Widget build(BuildContext context) {
    final contentWidth = widget.width - _frameInset * 2;
    final aspectRatio = _imageAspectRatio ?? _fallbackAspectRatio;
    final imageHeight = contentWidth / aspectRatio;

    return SizedBox(
      width: widget.width,
      child: _wrapCorners(
        ColoredBox(
          color: widget.textBackgroundColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _frameInset,
                  _frameInset,
                  _frameInset,
                  0,
                ),
                child: SizedBox(
                  width: contentWidth,
                  height: imageHeight,
                  child: ExportCardCenterImage(
                    localPath: widget.localPath,
                    remoteUrl: widget.remoteUrl,
                    width: contentWidth,
                    height: imageHeight,
                    onAspectRatioResolved: _onAspectRatioResolved,
                    onDisplayed: widget.onImageReady == null
                        ? null
                        : _onImageDisplayed,
                  ),
                ),
              ),
              Container(
                width: widget.width,
                color: widget.textBackgroundColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: _textInsetHorizontal,
                  vertical: _textInsetVertical,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OrganicBubble(
                      color: widget.textColor,
                      seed: widget.bubbleSeed,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.text,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wrapCorners(Widget child) {
    if (!widget.roundCorners) return child;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: widget.textBackgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}
