import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../api/api.dart';
import '../constants/app_colors.dart';
import '../constants/app_images.dart';
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
  final _textController = TextEditingController();

  static const _quoteBoxGap = 20.0;

  bool _loading = true;
  bool _regenerating = false;
  bool _exportSquareCorners = false;
  String? _errorMessage;
  PetTextResult? _result;
  String? _resolvedImageUrl;
  int _bubbleSeed = 0;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _generate();
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
        _bubbleSeed = Random().nextInt(1 << 31);
        _loading = false;
        _regenerating = false;
      });
      _textController.text = response.result.text;
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

  void _unfocus() {
    FocusManager.instance.primaryFocus?.unfocus();
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
          '它想说',
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
              color: AppColors.primary,
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
                backgroundColor: AppColors.primary,
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
    const contentInset = 16.0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final contentWidth = screenWidth - contentInset * 2;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return GestureDetector(
      onTap: _unfocus,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        fit: StackFit.expand,
        children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                0,
                24,
                0,
                24 + bottomInset,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48 - bottomInset,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: contentInset),
                      child: RepaintBoundary(
                        key: _exportKey,
                        child: PetCopyExportCard(
                          localPath: _displayLocalPath(),
                          remoteUrl: _displayRemoteUrl(),
                          text: _textController.text,
                          textBackgroundColor: result.backgroundColor,
                          bubbleSeed: _bubbleSeed,
                          width: contentWidth,
                          roundCorners: !_exportSquareCorners,
                        ),
                      ),
                    ),
                    SizedBox(height: _quoteBoxGap),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: contentInset),
                      child: GestureDetector(
                        onTap: _unfocus,
                        behavior: HitTestBehavior.translucent,
                        child: Container(
                          width: contentWidth,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Transform.rotate(
                                angle: pi,
                                child: Icon(
                                  Icons.format_quote,
                                  color: AppColors.textOnDark
                                      .withValues(alpha: 0.92),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _textController,
                                  minLines: 1,
                                  maxLines: null,
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.multiline,
                                  style: TextStyle(
                                    color: AppColors.textOnDark
                                        .withValues(alpha: 0.92),
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: '点击编辑文案',
                                    hintStyle: TextStyle(
                                      color: AppColors.textOnDark
                                          .withValues(alpha: 0.35),
                                      fontSize: 13,
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.format_quote,
                                color: AppColors.textOnDark
                                    .withValues(alpha: 0.92),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: _quoteBoxGap),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: contentInset),
                      child: SizedBox(
                        width: contentWidth,
                        child: _buildBottomActions(contentWidth),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
                        color: AppColors.primary,
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
        ],
      ),
    );
  }

  Widget _buildBottomActions(double totalWidth) {
    const gapFactor = 0.025;
    const widthHeightRatio = 1.65;
    final gap = totalWidth * gapFactor;
    final buttonWidth = (totalWidth - gap * 2) / 3;
    final buttonHeight = buttonWidth / widthHeightRatio;

    return SizedBox(
      width: totalWidth,
      child: Row(
        children: [
          SizedBox(
            width: buttonWidth,
            height: buttonHeight,
            child: _ActionTile(
              label: '重新生成',
              iconAsset: AppImages.regenerate,
              gradientStart: AppColors.aiCopyRegenerateGradientStart,
              gradientEnd: AppColors.aiCopyRegenerateGradientEnd,
              onTap: _regenerating ? null : _onRegenerate,
            ),
          ),
          SizedBox(width: gap),
          SizedBox(
            width: buttonWidth,
            height: buttonHeight,
            child: _ActionTile(
              label: '保存到相册',
              iconAsset: AppImages.save,
              gradientStart: AppColors.aiCopySaveGradientStart,
              gradientEnd: AppColors.aiCopySaveGradientEnd,
              onTap: _saveToGallery,
            ),
          ),
          SizedBox(width: gap),
          SizedBox(
            width: buttonWidth,
            height: buttonHeight,
            child: _ActionTile(
              label: '分享',
              iconAsset: AppImages.share,
              gradientStart: AppColors.aiCopyShareGradientStart,
              gradientEnd: AppColors.aiCopyShareGradientEnd,
              onTap: _shareCard,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  static const _iconSize = 26.0;
  static const _labelFontSize = 13.0;
  static const _cornerRadius = 16.0;

  final String label;
  final String iconAsset;
  final Color gradientStart;
  final Color gradientEnd;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.label,
    required this.iconAsset,
    required this.gradientStart,
    required this.gradientEnd,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final start =
        enabled ? gradientStart : gradientStart.withValues(alpha: 0.55);
    final end = enabled ? gradientEnd : gradientEnd.withValues(alpha: 0.55);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [start, end],
            ),
            borderRadius: BorderRadius.circular(_cornerRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  iconAsset,
                  width: _iconSize,
                  height: _iconSize,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.image_outlined,
                    color: Colors.white,
                    size: _iconSize,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: _labelFontSize,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
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
