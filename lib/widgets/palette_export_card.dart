import 'package:flutter/material.dart';

import '../services/photo_metadata_service.dart';
import 'export_card_center_image.dart';

/// 调色盘导出卡片：相框 + 原图 + 元数据信息区
class PaletteExportCard extends StatefulWidget {
  final String? localPath;
  final String? remoteUrl;
  final PhotoMetadata metadata;
  final Color bandColor;
  final Color textColor;
  final double width;
  final bool roundCorners;
  final VoidCallback? onImageReady;

  const PaletteExportCard({
    super.key,
    this.localPath,
    this.remoteUrl,
    required this.metadata,
    this.bandColor = Colors.white,
    this.textColor = const Color(0xFF1F2937),
    required this.width,
    this.roundCorners = true,
    this.onImageReady,
  });

  @override
  State<PaletteExportCard> createState() => _PaletteExportCardState();
}

class _PaletteExportCardState extends State<PaletteExportCard> {
  static const _frameInset = 16.0;
  static const _metadataInsetLeft = 50.0;
  static const _metadataInsetVertical = 25.0;
  static const _metadataRowGap = 8.0;
  static const _fallbackAspectRatio = 3 / 4;

  double? _imageAspectRatio;

  @override
  void didUpdateWidget(covariant PaletteExportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localPath != widget.localPath ||
        oldWidget.remoteUrl != widget.remoteUrl) {
      _imageAspectRatio = null;
    }
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
          color: widget.bandColor,
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
                color: widget.bandColor,
                padding: const EdgeInsets.fromLTRB(
                  _metadataInsetLeft,
                  _metadataInsetVertical,
                  _frameInset,
                  _metadataInsetVertical,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetadataRow(
                      icon: Icons.location_on_outlined,
                      text: widget.metadata.location,
                      textColor: widget.textColor,
                    ),
                    const SizedBox(height: _metadataRowGap),
                    _MetadataRow(
                      icon: Icons.schedule_outlined,
                      text: widget.metadata.capturedAt,
                      textColor: widget.textColor,
                    ),
                    const SizedBox(height: _metadataRowGap),
                    _MetadataRow(
                      icon: Icons.phone_iphone_outlined,
                      text: widget.metadata.device,
                      textColor: widget.textColor,
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
        color: widget.bandColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _MetadataRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color textColor;

  const _MetadataRow({
    required this.icon,
    required this.text,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: textColor.withValues(alpha: 0.75)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
