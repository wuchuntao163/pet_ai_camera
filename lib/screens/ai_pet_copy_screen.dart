import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../api/api.dart';
import '../constants/app_colors.dart';
import '../models/app_photo.dart';
import '../services/pet_text_service.dart';
import '../services/photo_gallery_service.dart';
import '../services/photo_share_service.dart';
import '../services/file_upload_service.dart';
import '../widgets/pet_copy_export_card.dart';
import '../widgets/toast_message.dart';

/// AI 趣味文案：加载 → 结果展示
class AiPetCopyScreen extends StatefulWidget {
  final AppPhoto photo;
  final PhotoGalleryService galleryService;

  const AiPetCopyScreen({
    super.key,
    required this.photo,
    required this.galleryService,
  });

  @override
  State<AiPetCopyScreen> createState() => _AiPetCopyScreenState();
}

class _AiPetCopyScreenState extends State<AiPetCopyScreen> {
  static const _pageBg = Color(0xFF0F1628);

  final _exportKey = GlobalKey();
  final _bottomBarKey = GlobalKey();

  static const _quoteBoxGap = 20.0;

  double _bottomBarHeight = 0;

  bool _loading = true;
  bool _regenerating = false;
  bool _exportSquareCorners = false;
  String? _errorMessage;
  PetTextResult? _result;
  String? _resolvedImageUrl;

  @override
  void initState() {
    super.initState();
    _generate();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateBottomBarHeight());
  }

  void _updateBottomBarHeight() {
    final box =
        _bottomBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !mounted) return;
    final height = box.size.height;
    if ((height - _bottomBarHeight).abs() > 0.5) {
      setState(() => _bottomBarHeight = height);
    }
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final local = widget.photo.hasLocalFile ? widget.photo.localPath : null;
      final response = await PetTextService.generate(
        imageUrl: _resolvedImageUrl ?? widget.photo.remoteUrl,
        localPath: _resolvedImageUrl == null ? local : null,
      );
      if (!mounted) return;
      setState(() {
        _result = response.result;
        _resolvedImageUrl = response.imageUrl;
        _loading = false;
        _regenerating = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _regenerating = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _regenerating = false;
        _errorMessage = e is ApiException
            ? e.message
            : (e is StateError ? e.message : '生成失败，请重试');
      });
    }
  }

  Future<void> _onRegenerate() async {
    if (_regenerating) return;
    setState(() => _regenerating = true);
    await _generate();
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

  String? _displayLocalPath() {
    // 生成成功后优先用已上传 URL 展示，避免 release 下本地缓存路径失效
    if (_resolvedImageUrl != null && _resolvedImageUrl!.isNotEmpty) {
      return null;
    }
    final path = widget.photo.localPath.trim();
    if (path.isEmpty || !File(path).existsSync()) return null;
    return path;
  }

  String? _displayRemoteUrl() {
    final raw = _resolvedImageUrl ?? widget.photo.remoteUrl;
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();
    if (value.startsWith('http')) return value;
    return FileUploadService.resolveUrl(value);
  }

  Future<String?> _writeTempPng(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/pet_ai_copy_${DateTime.now().millisecondsSinceEpoch}.png';
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
      if (mounted) {
        ToastMessage.show(context, '需要相册权限才能保存');
      }
      return;
    }

    try {
      final path = await _writeTempPng(bytes);
      if (path == null) throw StateError('temp file');
      await PhotoManager.editor.saveImageWithPath(
        path,
        title: 'pet_ai_copy_${DateTime.now().millisecondsSinceEpoch}',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: AppColors.textOnDark,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'AI趣味文案',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading && _result == null
          ? _buildLoadingBody()
          : _errorMessage != null && _result == null
              ? _buildErrorBody()
              : _buildResultBody(),
    );
  }

  Widget _buildLoadingBody() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.recordRed,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'AI正在分析照片...',
            style: TextStyle(
              color: AppColors.textOnDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '识别宠物情绪，生成趣味文案',
            style: TextStyle(
              color: AppColors.textOnDark.withValues(alpha: 0.55),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage ?? '生成失败',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textOnDark.withValues(alpha: 0.8),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _generate,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.recordRed,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultBody() {
    final result = _result!;
    const horizontalInset = 16.0;
    final width = MediaQuery.sizeOf(context).width - horizontalInset * 2;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final bottomBarHeight = _bottomBarHeight > 0 ? _bottomBarHeight : 68.0;
    final scrollBottomPadding = bottomBarHeight + safeBottom + _quoteBoxGap;

    WidgetsBinding.instance.addPostFrameCallback((_) => _updateBottomBarHeight());

    return Stack(
      fit: StackFit.expand,
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalInset,
            0,
            horizontalInset,
            scrollBottomPadding,
          ),
          child: Column(
            children: [
              RepaintBoundary(
                key: _exportKey,
                child: PetCopyExportCard(
                  localPath: _displayLocalPath(),
                  remoteUrl: _displayRemoteUrl(),
                  text: result.text,
                  textBackgroundColor: result.backgroundColor,
                  width: width,
                  roundCorners: !_exportSquareCorners,
                ),
              ),
              SizedBox(height: _quoteBoxGap),
              Container(
                width: width,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A3344),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.format_quote,
                      color: AppColors.recordRed,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.text,
                        style: TextStyle(
                          color: AppColors.textOnDark.withValues(alpha: 0.92),
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_regenerating)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0x66000000),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.recordRed,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '正在重新生成...',
                      style: TextStyle(
                        color: AppColors.textOnDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '识别宠物情绪，生成趣味文案',
                      style: TextStyle(
                        color: AppColors.textOnDark.withValues(alpha: 0.55),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              key: _bottomBarKey,
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildBottomActions(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _ActionTile(
              label: '重新生成',
              icon: Icons.refresh,
              colors: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
              onTap: _regenerating ? null : _onRegenerate,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionTile(
              label: '保存到相册',
              icon: Icons.save_alt_outlined,
              colors: const [Color(0xFFFF8FC7), Color(0xFFE91E8C)],
              onTap: _saveToGallery,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionTile(
              label: '分享',
              icon: Icons.share_outlined,
              colors: const [Color(0xFF8B5CF6), Color(0xFF6366F1)],
              onTap: _shareCard,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.label,
    required this.icon,
    required this.colors,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
