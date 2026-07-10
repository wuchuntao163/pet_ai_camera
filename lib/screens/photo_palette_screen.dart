import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../models/app_photo.dart';
import '../router/app_routes.dart';
import '../screens/system_photo_picker_screen.dart';
import '../services/file_upload_service.dart';
import '../services/photo_gallery_service.dart';
import '../services/photo_metadata_service.dart';
import '../services/photo_share_service.dart';
import '../services/pet_text_service.dart';
import '../widgets/gallery_app_bar_action.dart';
import '../widgets/palette_export_card.dart';
import '../widgets/toast_message.dart';

/// 调色盘：展示照片拍摄地点、时间、设备
class PhotoPaletteScreen extends StatefulWidget {
  final AppPhoto photo;
  final PhotoGalleryService galleryService;

  const PhotoPaletteScreen({
    super.key,
    required this.photo,
    required this.galleryService,
  });

  @override
  State<PhotoPaletteScreen> createState() => _PhotoPaletteScreenState();
}

class _PhotoPaletteScreenState extends State<PhotoPaletteScreen> {
  static const _pageBg = Color(0xFF0F1628);

  final _exportKey = GlobalKey();

  late AppPhoto _photo;
  bool _loading = true;
  bool _exportSquareCorners = false;
  PhotoMetadata? _metadata;
  Color _bandColor = Colors.white;
  String? _resolvedImageUrl;

  @override
  void initState() {
    super.initState();
    _photo = widget.photo;
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() {
      _loading = true;
      _resolvedImageUrl = null;
    });

    final metadataFuture =
        PhotoMetadataService.resolve(_photo, galleryService: widget.galleryService);
    var bandColor = Colors.white;
    String? resolvedUrl;

    try {
      final local = _photo.hasLocalFile ? _photo.localPath : null;
      final response = await PetTextService.generate(
        imageUrl: _photo.remoteUrl,
        localPath: local,
      );
      bandColor = response.result.backgroundColor;
      resolvedUrl = response.imageUrl;
    } catch (_) {
      // 接口失败时保留白色兜底
    }

    final metadata = await metadataFuture;
    if (!mounted) return;
    setState(() {
      _metadata = metadata;
      _bandColor = bandColor;
      _resolvedImageUrl = resolvedUrl;
      _loading = false;
    });
  }

  String? _displayLocalPath() {
    if (_resolvedImageUrl != null && _resolvedImageUrl!.isNotEmpty) {
      return null;
    }
    final path = _photo.localPath.trim();
    if (path.isEmpty || !File(path).existsSync()) return null;
    return path;
  }

  String? _displayRemoteUrl() {
    final raw = _resolvedImageUrl ?? _photo.remoteUrl;
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();
    if (value.startsWith('http')) return value;
    return FileUploadService.resolveUrl(value);
  }

  Future<void> _replacePhoto() async {
    final granted = await widget.galleryService.ensurePermission();
    if (!mounted) return;
    if (!granted) {
      ToastMessage.show(context, '需要相册权限才能选择照片');
      return;
    }

    final picked = await Navigator.of(context).push<AppPhoto>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const SystemPhotoPickerScreen(),
      ),
    );
    if (!mounted || picked == null) return;

    setState(() {
      _photo = picked;
      _resolvedImageUrl = null;
    });
    await _loadContent();
  }

  Future<Uint8List?> _captureCardPng() async {
    setState(() => _exportSquareCorners = true);
    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      final boundary = _exportKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return byteData?.buffer.asUint8List();
    } finally {
      if (mounted) {
        setState(() => _exportSquareCorners = false);
      }
    }
  }

  Future<String?> _writeTempPng(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/pet_palette_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  Future<void> _saveToGallery() async {
    final bytes = await _captureCardPng();
    if (bytes == null) {
      if (mounted) ToastMessage.show(context, '保存失败，请重试');
      return;
    }
    if (!await widget.galleryService.ensurePermission()) {
      if (mounted) ToastMessage.show(context, '需要相册权限才能保存');
      return;
    }

    try {
      final path = await _writeTempPng(bytes);
      if (path == null) throw StateError('temp file');
      await PhotoManager.editor.saveImageWithPath(
        path,
        title: 'pet_palette_${DateTime.now().millisecondsSinceEpoch}',
        relativePath: 'Pictures/PetAiCamera',
      );
      if (mounted) ToastMessage.show(context, '已保存到相册');
    } catch (_) {
      if (mounted) ToastMessage.show(context, '保存失败，请重试');
    }
  }

  Future<void> _shareCard() async {
    final bytes = await _captureCardPng();
    if (bytes == null) {
      if (mounted) ToastMessage.show(context, '分享失败，请重试');
      return;
    }
    try {
      final path = await _writeTempPng(bytes);
      if (path == null) throw StateError('temp file');
      await PhotoShareService.sharePaths([path]);
    } catch (_) {
      if (mounted) ToastMessage.show(context, '分享失败，请重试');
    }
  }

  void _onWantToSay() {
    context.push(AppRoutes.aiPetCopy, extra: _photo);
  }

  Future<void> _showExportMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1C2438),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save_alt_outlined, color: Colors.white),
              title: const Text('保存到相册', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(ctx).pop('save'),
            ),
            ListTile(
              leading: Image.asset(
                AppImages.share,
                width: 22,
                height: 22,
                fit: BoxFit.contain,
              ),
              title: const Text('分享', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(ctx).pop('share'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    if (action == 'save') {
      await _saveToGallery();
    } else if (action == 'share') {
      await _shareCard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: AppColors.textOnDark,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          '调色盘',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: '替换图片',
            onPressed: _replacePhoto,
            icon: const Icon(Icons.add, size: 24),
          ),
          GalleryAppBarAction(
            assetPath: AppImages.share,
            tooltip: '下载/分享',
            onPressed: _showExportMenu,
          ),
          GalleryAppBarAction(
            assetPath: AppImages.wantToSay,
            tooltip: '它想说',
            onPressed: _onWantToSay,
          ),
        ],
      ),
      body: _loading || _metadata == null
          ? _buildLoadingBody()
          : _buildBody(_metadata!),
    );
  }

  Widget _buildLoadingBody() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
              backgroundColor: Colors.white12,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '正在加载调色盘...',
            style: TextStyle(
              color: AppColors.textOnDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '读取照片信息与配色',
            style: TextStyle(
              color: AppColors.textOnDark.withValues(alpha: 0.55),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(PhotoMetadata metadata) {
    const horizontalInset = 16.0;
    final width = MediaQuery.sizeOf(context).width - horizontalInset * 2;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: horizontalInset, vertical: 24),
        child: RepaintBoundary(
          key: _exportKey,
          child: PaletteExportCard(
            localPath: _displayLocalPath(),
            remoteUrl: _displayRemoteUrl(),
            metadata: metadata,
            bandColor: _bandColor,
            width: width,
            roundCorners: !_exportSquareCorners,
          ),
        ),
      ),
    );
  }
}
