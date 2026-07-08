import 'dart:io';

import 'package:flutter/material.dart';

import '../services/file_upload_service.dart';
import '../services/photo_metadata_service.dart';

/// 调色盘导出卡片：相框 + 原图 + 元数据信息区
class PaletteExportCard extends StatefulWidget {
  final String? localPath;
  final String? remoteUrl;
  final PhotoMetadata metadata;
  final Color bandColor;
  final Color textColor;
  final double width;
  final bool roundCorners;

  const PaletteExportCard({
    super.key,
    this.localPath,
    this.remoteUrl,
    required this.metadata,
    this.bandColor = Colors.white,
    this.textColor = const Color(0xFF1F2937),
    required this.width,
    this.roundCorners = true,
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
  ImageStreamListener? _aspectListener;
  ImageStream? _aspectStream;

  @override
  void initState() {
    super.initState();
    _resolveImageAspectRatio();
  }

  @override
  void didUpdateWidget(covariant PaletteExportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localPath != widget.localPath ||
        oldWidget.remoteUrl != widget.remoteUrl) {
      _disposeAspectListener();
      _imageAspectRatio = null;
      _resolveImageAspectRatio();
    }
  }

  @override
  void dispose() {
    _disposeAspectListener();
    super.dispose();
  }

  void _disposeAspectListener() {
    if (_aspectListener != null && _aspectStream != null) {
      _aspectStream!.removeListener(_aspectListener!);
    }
    _aspectListener = null;
    _aspectStream = null;
  }

  void _resolveImageAspectRatio() {
    ImageProvider? provider;
    final localPath = widget.localPath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        provider = FileImage(file);
      }
    }
    provider ??= _networkProvider(widget.remoteUrl);
    if (provider == null) return;

    final stream = provider.resolve(const ImageConfiguration());
    _aspectStream = stream;
    _aspectListener = ImageStreamListener(
      (info, _) {
        final width = info.image.width.toDouble();
        final height = info.image.height.toDouble();
        if (height <= 0 || !mounted) return;
        setState(() => _imageAspectRatio = width / height);
      },
      onError: (_, __) {},
    );
    stream.addListener(_aspectListener!);
  }

  NetworkImage? _networkProvider(String? url) {
    final value = _resolvedRemoteUrl(raw: url);
    if (value == null || value.isEmpty) return null;
    return NetworkImage(value);
  }

  String? _resolvedRemoteUrl({String? raw}) {
    final value = (raw ?? widget.remoteUrl)?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http')) return value;
    return FileUploadService.resolveUrl(value);
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
                  child: _buildPhoto(contentWidth, imageHeight),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: child,
    );
  }

  Widget _buildPhoto(double photoWidth, double photoHeight) {
    final localPath = widget.localPath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: photoWidth,
          height: photoHeight,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              _networkOrPlaceholder(photoWidth, photoHeight),
        );
      }
    }
    return _networkOrPlaceholder(photoWidth, photoHeight);
  }

  Widget _networkOrPlaceholder(double photoWidth, double photoHeight) {
    final url = _resolvedRemoteUrl();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: photoWidth,
        height: photoHeight,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _placeholder(photoWidth, photoHeight),
      );
    }
    return _placeholder(photoWidth, photoHeight);
  }

  Widget _placeholder(double photoWidth, double photoHeight) {
    return ColoredBox(
      color: const Color(0xFF27272A),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: photoWidth * 0.2,
          color: Colors.white38,
        ),
      ),
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
