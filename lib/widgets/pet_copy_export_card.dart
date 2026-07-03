import 'dart:io';

import 'package:flutter/material.dart';

import '../services/file_upload_service.dart';
import '../services/pet_text_service.dart';

/// AI 趣味文案导出卡片（相框：内边距 + 原图完整显示 + 底色文案区）
class PetCopyExportCard extends StatefulWidget {
  final String? localPath;
  final String? remoteUrl;
  final String text;
  final Color textBackgroundColor;
  final Color textColor;
  final double width;
  final bool roundCorners;

  const PetCopyExportCard({
    super.key,
    this.localPath,
    this.remoteUrl,
    required this.text,
    required this.textBackgroundColor,
    this.textColor = kPetCopyTextColor,
    required this.width,
    this.roundCorners = true,
  });

  @override
  State<PetCopyExportCard> createState() => _PetCopyExportCardState();
}

class _PetCopyExportCardState extends State<PetCopyExportCard> {
  static const _frameInset = 10.0;
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
  void didUpdateWidget(covariant PetCopyExportCard oldWidget) {
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
    final textBandHeight = widget.width * 0.22;

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
                  child: _buildPhoto(contentWidth, imageHeight),
                ),
              ),
              Container(
                width: widget.width,
                height: textBandHeight,
                color: widget.textBackgroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: Colors.white,
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
