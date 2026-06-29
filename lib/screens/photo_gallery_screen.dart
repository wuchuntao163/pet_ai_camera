import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../models/app_photo.dart';
import '../router/app_routes.dart';
import '../services/photo_gallery_service.dart';
import '../services/photo_share_service.dart';
import '../widgets/app_photo_image.dart';
import '../widgets/toast_message.dart';

/// 本应用拍摄照片相册
class PhotoGalleryScreen extends StatefulWidget {
  final PhotoGalleryService galleryService;

  const PhotoGalleryScreen({super.key, required this.galleryService});

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  List<AppPhoto> _photos = [];
  bool _isBatchMode = false;
  bool _isLoading = true;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    await widget.galleryService.waitForPendingUploads();
    await widget.galleryService.refreshFromServer();
    if (!mounted) return;
    setState(() {
      _syncPhotos();
      _isLoading = false;
    });
  }

  void _syncPhotos() {
    _photos = List.of(widget.galleryService.cloudGalleryPhotos);
    _selectedIds.removeWhere(
      (id) => !_photos.any((photo) => photo.id == id),
    );
    if (_photos.isEmpty) {
      _isBatchMode = false;
      _selectedIds.clear();
    }
  }

  void _exitBatchMode() {
    setState(() {
      _isBatchMode = false;
      _selectedIds.clear();
    });
  }

  void _enterBatchMode() {
    if (_photos.isEmpty) return;
    setState(() {
      _isBatchMode = true;
      _selectedIds.clear();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _photos.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_photos.map((photo) => photo.id));
      }
    });
  }

  void _togglePhotoSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  List<String> _pathsForIds(Set<String> ids) {
    return _photos
        .where((photo) => ids.contains(photo.id) && photo.hasLocalFile)
        .map((photo) => photo.localPath)
        .toList();
  }

  Future<void> _sharePaths(List<String> paths) async {
    if (paths.isEmpty) return;

    try {
      await PhotoShareService.sharePaths(paths);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('分享失败，请重试')),
        );
      }
    }
  }

  Future<void> _shareSelected() async {
    await _sharePaths(_pathsForIds(_selectedIds));
  }

  Future<void> _openPhotoViewer(int initialIndex) async {
    if (_isBatchMode) {
      _togglePhotoSelection(_photos[initialIndex].id);
      return;
    }
    await context.push<void>(AppRoutes.galleryPhoto(initialIndex));
    if (mounted) setState(_syncPhotos);
  }

  Future<bool> _confirmDeleteMessage({
    required String title,
    required String content,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(title, style: const TextStyle(color: AppColors.textOnDark)),
        content: Text(content, style: const TextStyle(color: AppColors.textHint)),
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
    return confirmed == true;
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final count = _selectedIds.length;
    final confirmed = await _confirmDeleteMessage(
      title: '删除选中照片',
      content: '将从本应用和系统相册中删除 $count 张照片，确定吗？',
    );
    if (!confirmed || !mounted) return;

    final result =
        await widget.galleryService.deletePhotos(_selectedIds.toList());
    if (!mounted) return;

    if (result.deleted == 0) {
      if (result.msg.isNotEmpty) {
        ToastMessage.show(context, result.msg);
      }
      return;
    }

    setState(_syncPhotos);
    if (result.msg.isNotEmpty) {
      ToastMessage.show(context, result.msg);
    }
  }

  Future<void> _deleteAll() async {
    if (_photos.isEmpty) return;

    final confirmed = await _confirmDeleteMessage(
      title: '全部删除',
      content: '将从本应用和系统相册中删除全部 ${_photos.length} 张照片，确定吗？',
    );
    if (!confirmed || !mounted) return;

    final result = await widget.galleryService.deleteAllPhotos();
    if (!mounted) return;

    if (result.deleted == 0) {
      if (result.msg.isNotEmpty) {
        ToastMessage.show(context, result.msg);
      }
      return;
    }

    setState(_syncPhotos);
    if (result.msg.isNotEmpty) {
      ToastMessage.show(context, result.msg);
    }
  }

  Widget _assetAction({
    required String assetPath,
    required String tooltip,
    required Key key,
    VoidCallback? onPressed,
  }) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Image.asset(
        assetPath,
        width: 22,
        height: 22,
        fit: BoxFit.contain,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cameraBg,
      appBar: AppBar(
        backgroundColor: AppColors.cameraBg,
        foregroundColor: AppColors.textOnDark,
        elevation: 0,
        title: Text(_isBatchMode ? '已选 ${_selectedIds.length} 张' : '我的照片'),
        leading: IconButton(
          icon: Icon(_isBatchMode ? Icons.close : Icons.arrow_back_ios_new,
              size: 20),
          onPressed: () {
            if (_isBatchMode) {
              _exitBatchMode();
            } else {
              context.pop();
            }
          },
        ),
        actions: [
          if (_photos.isNotEmpty && !_isBatchMode) ...[
            _assetAction(
              key: const Key('gallery_batch'),
              assetPath: AppImages.galleryBatchEdit,
              tooltip: '批量编辑',
              onPressed: _enterBatchMode,
            ),
            _assetAction(
              key: const Key('gallery_delete_all'),
              assetPath: AppImages.galleryDeleteAll,
              tooltip: '全部删除',
              onPressed: _deleteAll,
            ),
          ],
          if (_isBatchMode) ...[
            _assetAction(
              key: const Key('gallery_select_all'),
              assetPath: AppImages.gallerySelectAll,
              tooltip:
                  _selectedIds.length == _photos.length ? '取消全选' : '全选',
              onPressed: _toggleSelectAll,
            ),
            if (_selectedIds.isNotEmpty)
              _assetAction(
                key: const Key('gallery_share_selected'),
                assetPath: AppImages.galleryShare,
                tooltip: '分享选中',
                onPressed: _shareSelected,
              ),
            IconButton(
              key: const Key('gallery_delete_selected'),
              tooltip: '删除选中',
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
              icon: Icon(
                Icons.delete_outline,
                size: 22,
                color: _selectedIds.isEmpty
                    ? AppColors.textHint
                    : AppColors.recordRed,
              ),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
          ? const Center(
              child: Text(
                '还没有拍摄照片',
                style: TextStyle(color: AppColors.textHint, fontSize: 16),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: _photos.length,
              itemBuilder: (context, index) {
                final photo = _photos[index];
                final selected = _selectedIds.contains(photo.id);
                return GestureDetector(
                  onTap: () => _openPhotoViewer(index),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppPhotoImage(
                        photo: photo,
                        fit: BoxFit.cover,
                      ),
                      if (_isBatchMode)
                        Container(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.35)
                              : const Color(0x33000000),
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                selected
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textOnDark,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
