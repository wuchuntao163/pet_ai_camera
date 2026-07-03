import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../constants/app_colors.dart';
import '../services/system_photo_picker_service.dart';
import '../widgets/toast_message.dart';

/// 系统相册选图（单张，用于 AI 趣味文案）
class SystemPhotoPickerScreen extends StatefulWidget {
  const SystemPhotoPickerScreen({super.key});

  @override
  State<SystemPhotoPickerScreen> createState() =>
      _SystemPhotoPickerScreenState();
}

class _SystemPhotoPickerScreenState extends State<SystemPhotoPickerScreen> {
  List<AssetEntity> _assets = [];
  bool _loading = true;
  bool _processing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final assets = await SystemPhotoPickerService.loadRecentPhotos();
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _loading = false;
        _errorMessage = assets.isEmpty ? '系统相册中没有照片' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = '读取相册失败，请重试';
      });
    }
  }

  Future<void> _onPick(AssetEntity asset) async {
    if (_processing) return;

    setState(() => _processing = true);
    try {
      final photo = await SystemPhotoPickerService.appPhotoFromAsset(asset);
      if (!mounted) return;
      if (photo == null) {
        ToastMessage.show(context, '读取照片失败，请重试');
        setState(() => _processing = false);
        return;
      }
      Navigator.of(context).pop(photo);
    } catch (_) {
      if (!mounted) return;
      ToastMessage.show(context, '读取照片失败，请重试');
      setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cameraBg,
      appBar: AppBar(
        backgroundColor: AppColors.cameraBg,
        foregroundColor: AppColors.textOnDark,
        elevation: 0,
        title: const Text('选择照片'),
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22),
          onPressed: _processing ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          _buildBody(),
          if (_processing)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.recordRed),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.recordRed),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loadAssets,
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

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _assets.length,
      itemBuilder: (context, index) {
        final asset = _assets[index];
        return GestureDetector(
          onTap: () => _onPick(asset),
          child: _AssetThumbnail(asset: asset),
        );
      },
    );
  }
}

class _AssetThumbnail extends StatelessWidget {
  final AssetEntity asset;

  const _AssetThumbnail({required this.asset});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize.square(300)),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return Image.memory(bytes, fit: BoxFit.cover);
        }
        return const ColoredBox(
          color: Color(0xFF27272A),
          child: Center(
            child: Icon(
              Icons.image_outlined,
              color: AppColors.textHint,
              size: 28,
            ),
          ),
        );
      },
    );
  }
}
