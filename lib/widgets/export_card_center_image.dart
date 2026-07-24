import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/file_upload_service.dart';

/// 导出卡片中间照片：解析宽高比，并在首帧绘制完成后回调。
class ExportCardCenterImage extends StatefulWidget {
  final String? localPath;
  final String? remoteUrl;
  final double width;
  final double height;
  final ValueChanged<double>? onAspectRatioResolved;
  final VoidCallback? onDisplayed;

  const ExportCardCenterImage({
    super.key,
    this.localPath,
    this.remoteUrl,
    required this.width,
    required this.height,
    this.onAspectRatioResolved,
    this.onDisplayed,
  });

  @override
  State<ExportCardCenterImage> createState() => _ExportCardCenterImageState();
}

class _ExportCardCenterImageState extends State<ExportCardCenterImage> {
  ImageProvider? _provider;
  ImageStreamListener? _aspectListener;
  ImageStream? _aspectStream;
  bool _aspectRatioKnown = false;
  bool _displayFrameReady = false;
  bool _displayNotified = false;

  @override
  void initState() {
    super.initState();
    _bindProvider();
  }

  @override
  void didUpdateWidget(covariant ExportCardCenterImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localPath != widget.localPath ||
        oldWidget.remoteUrl != widget.remoteUrl) {
      _resetReadyState();
      _bindProvider();
    }
  }

  @override
  void dispose() {
    _disposeAspectListener();
    super.dispose();
  }

  void _resetReadyState() {
    _disposeAspectListener();
    _aspectRatioKnown = false;
    _displayFrameReady = false;
    _displayNotified = false;
  }

  void _bindProvider() {
    _provider = _resolveProvider();
    if (_provider == null) {
      _aspectRatioKnown = true;
      _markDisplayFrameReady();
      return;
    }

    final stream = _provider!.resolve(const ImageConfiguration());
    _aspectStream = stream;
    _aspectListener = ImageStreamListener(
      (info, _) {
        final width = info.image.width.toDouble();
        final height = info.image.height.toDouble();
        if (height <= 0 || !mounted) return;
        widget.onAspectRatioResolved?.call(width / height);
        _aspectRatioKnown = true;
        _tryNotifyDisplayed();
      },
      onError: (_, __) {
        if (!mounted) return;
        _aspectRatioKnown = true;
        _tryNotifyDisplayed();
      },
    );
    stream.addListener(_aspectListener!);
  }

  void _disposeAspectListener() {
    if (_aspectListener != null && _aspectStream != null) {
      _aspectStream!.removeListener(_aspectListener!);
    }
    _aspectListener = null;
    _aspectStream = null;
  }

  void _markDisplayFrameReady() {
    if (_displayFrameReady) return;
    _displayFrameReady = true;
    _tryNotifyDisplayed();
  }

  void _tryNotifyDisplayed() {
    if (_displayNotified || widget.onDisplayed == null) return;
    if (!_aspectRatioKnown || !_displayFrameReady) return;
    _displayNotified = true;
    SchedulerBinding.instance.scheduleFrame();
    widget.onDisplayed!.call();
  }

  ImageProvider? _resolveProvider() {
    final localPath = widget.localPath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }
    final url = _resolvedRemoteUrl();
    if (url == null || url.isEmpty) return null;
    return NetworkImage(url);
  }

  String? _resolvedRemoteUrl() {
    final value = widget.remoteUrl?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http')) return value;
    return FileUploadService.resolveUrl(value);
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (provider == null) {
      return _placeholder();
    }

    return Image(
      image: provider,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null || wasSynchronouslyLoaded) {
          _markDisplayFrameReady();
        }
        return child;
      },
      errorBuilder: (_, __, ___) {
        _aspectRatioKnown = true;
        _markDisplayFrameReady();
        return _placeholder();
      },
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: const Color(0xFF27272A),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: widget.width * 0.2,
          color: Colors.white38,
        ),
      ),
    );
  }
}
