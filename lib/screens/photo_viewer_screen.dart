import 'package:flutter/material.dart';import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../models/app_photo.dart';
import '../constants/app_images.dart';
import '../services/photo_gallery_service.dart';
import '../services/photo_share_service.dart';
import '../widgets/app_photo_image.dart';
import '../widgets/toast_message.dart';

/// 单张/多张照片查看（左右滑动）
class PhotoViewerScreen extends StatefulWidget {
  final PhotoGalleryService galleryService;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.galleryService,
    required this.initialIndex,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late PageController _pageController;
  late List<AppPhoto> _photos;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _photos = List.of(widget.galleryService.cloudGalleryPhotos);
    _currentIndex = widget.initialIndex.clamp(0, _photos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    if (_photos.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          '删除照片',
          style: TextStyle(color: AppColors.textOnDark),
        ),
        content: const Text(
          '将从本应用和系统相册中删除这张照片，确定吗？',
          style: TextStyle(color: AppColors.textHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '删除',
              style: TextStyle(color: AppColors.recordRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final photo = _photos[_currentIndex];
    final result = await widget.galleryService.deletePhoto(photo.id);
    if (!mounted) return;

    if (!result.ok) {
      if (result.msg.isNotEmpty) {
        ToastMessage.show(context, result.msg);
      }
      return;
    }

    setState(() {
      _photos.removeAt(_currentIndex);
    });

    if (_photos.isEmpty) {
      context.pop();
      return;
    }

    final nextIndex = _currentIndex.clamp(0, _photos.length - 1);
    _currentIndex = nextIndex;
    _pageController.jumpToPage(nextIndex);
    setState(() {});
  }

  Future<void> _shareCurrent() async {
    if (_photos.isEmpty) return;
    final photo = _photos[_currentIndex];
    if (!photo.hasLocalFile) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('云端照片暂不支持分享')),
        );
      }
      return;
    }
    try {
      await PhotoShareService.sharePaths([photo.localPath]);
    } catch (e) {
      debugPrint('PhotoViewerScreen share failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('分享失败，请重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: AppColors.textOnDark,
        elevation: 0,
        title: Text('${_currentIndex + 1} / ${_photos.length}'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: '分享',
            onPressed: _shareCurrent,
            icon: Image.asset(
              AppImages.galleryShare,
              width: 22,
              height: 22,
              fit: BoxFit.contain,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _photos.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: AppPhotoImage(
                photo: _photos[index],
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
