import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../models/camera_config.dart';
import '../models/camera_toolbar.dart';
import '../services/camera_service.dart';
import '../services/photo_crop_service.dart';
import '../constants/app_sizes.dart';
import '../widgets/camera_top_bar.dart';
import '../widgets/camera_bottom_bar.dart';
import '../widgets/pet_emoji_button.dart';
import '../widgets/zoom_control.dart';
import '../widgets/camera_preview_view.dart';

import '../widgets/capture_shutter_overlay.dart';
import '../widgets/countdown_overlay.dart';
import '../widgets/camera_tool_popups.dart';
import '../services/sidebar_sound_store.dart';
import '../data/app_cache_store.dart';
import '../data/camera_sound_store.dart';
import 'settings_screen.dart';
import 'sound_library_screen.dart';
import 'package:go_router/go_router.dart';
import '../app/app_services.dart';
import '../router/app_routes.dart';

/// 相机主界面
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  final _cameraService = CameraService();
  final _photoGallery = AppServices.instance.photoGallery;
  final _settings = AppServices.instance.cameraSettings;
  double _currentZoom = 1.0;
  bool _isPhotoMode = true;
  bool _isLoading = true;
  String? _errorMessage;
  CameraPermissionState? _cameraPermissionState;
  bool _lifecyclePaused = false;

  int _aspectRatioIndex = AspectRatioOption.defaultIndex;
  FlashToolbarState _flashState = FlashToolbarState.off;
  CameraPopupType _activePopup = CameraPopupType.none;

  bool _isCapturing = false;
  bool _isGalleryLoading = false;
  double _flashOpacity = 0;
  int? _countdown;
  int _lastPhotoRevision = 0;
  String? _galleryThumbLocalPath;
  String? _galleryThumbRemoteUrl;
  bool _galleryThumbPreferCloud = false;
  Uint8List? _galleryThumbBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings.addListener(_onSettingsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    await _photoGallery.init();
    if (mounted) {
      setState(() => _syncGalleryThumbFromLatest(preferCloud: false));
    }
    await _initCamera();
  }

  void _applyCaptureGalleryThumb(
    String localPath, {
    String? thumbnailPath,
  }) {
    _galleryThumbPreferCloud = false;
    _galleryThumbLocalPath = thumbnailPath ?? localPath;
    _galleryThumbRemoteUrl = null;
    _lastPhotoRevision++;
  }

  void _syncGalleryThumbFromLatest({required bool preferCloud}) {
    final latest = _photoGallery.latestPhoto;
    final hadMemoryThumb = _galleryThumbBytes != null && _galleryThumbBytes!.isNotEmpty;
    final previousLocalPath = _galleryThumbLocalPath;
    final previousRemoteUrl = _galleryThumbRemoteUrl;

    _galleryThumbPreferCloud = preferCloud;
    if (latest == null) {
      final hadVisibleThumb = hadMemoryThumb ||
          previousLocalPath != null ||
          previousRemoteUrl != null;
      _galleryThumbLocalPath = null;
      _galleryThumbRemoteUrl = null;
      _galleryThumbBytes = null;
      _galleryThumbPreferCloud = false;
      if (hadVisibleThumb) _lastPhotoRevision++;
      return;
    }

    // 内存缩略图仅用于刚拍完；从相册/索引同步时以 latest 为准
    _galleryThumbBytes = null;

    if (preferCloud) {
      _galleryThumbLocalPath = null;
      _galleryThumbRemoteUrl = latest.remoteUrl;
    } else if (latest.hasLocalFile) {
      _galleryThumbLocalPath = latest.localPath;
      _galleryThumbRemoteUrl = latest.remoteUrl;
    } else {
      _galleryThumbLocalPath = null;
      _galleryThumbRemoteUrl = latest.remoteUrl;
      _galleryThumbPreferCloud = latest.remoteUrl != null;
    }

    final displayChanged = hadMemoryThumb ||
        previousLocalPath != _galleryThumbLocalPath ||
        previousRemoteUrl != _galleryThumbRemoteUrl;
    if (displayChanged) {
      _lastPhotoRevision++;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings.removeListener(_onSettingsChanged);
    _cameraService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lifecyclePaused = true;
      _cameraService.pause();
    } else if (state == AppLifecycleState.resumed && _lifecyclePaused) {
      _lifecyclePaused = false;
      _initCamera();
    }
  }

  AspectRatioOption get _aspectRatio =>
      AspectRatioOption.all[_aspectRatioIndex];
  BurstOption get _burst => BurstOption.all[_settings.burstIndex];
  TimerOption get _timer => TimerOption.all[_settings.timerIndex];

  double get _previewVerticalAlignY => _aspectRatio.usesFullScreenPreview
      ? 0.5
      : AppSizes.previewVerticalAlignY;

  /// 9:16 全屏：原生 ViewPort 用屏幕比例铺满；3:4 走 contain 不设置
  double? _nativeViewportAspect(MediaQueryData mq) {
    if (_aspectRatio.usesNativeSensorOutput) return null;
    if (_aspectRatio.usesFullScreenPreview) {
      final h = mq.size.height.clamp(1.0, double.infinity);
      return mq.size.width / h;
    }
    return null;
  }

  /// 预览/裁切参考区域（全屏模式 = 整屏，与预览 WYSIWYG）
  Size _previewAreaSize(MediaQueryData mq) {
    if (_aspectRatio.usesFullScreenPreview) {
      return mq.size;
    }
    final h = (mq.size.height -
            AppSizes.topBarHeight -
            AppSizes.cameraBottomChrome)
        .clamp(1.0, mq.size.height);
    return Size(mq.size.width, h);
  }

  Future<void> _syncPreviewModeForAspect() async {
    if (!_cameraService.isInitialized || !mounted) return;
    final mq = MediaQuery.of(context);
    await _cameraService.setPreviewMode(
      nativeSensorContain: _aspectRatio.usesNativeSensorOutput,
      viewportAspect: _nativeViewportAspect(mq),
    );
  }

  Future<void> _initCamera() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _cameraPermissionState = null;
    });

    try {
      await _cameraService.initialize();
      final baseline = await _cameraService.ensureBaselineOneX();
      _currentZoom = baseline;
      await _cameraService.setZoomLevel(baseline);
      await _applyFlashState(_flashState);
      await _syncPreviewModeForAspect();
      if (mounted) setState(() => _isLoading = false);
    } on CameraPermissionException {
      final permissionState = await _cameraService.getCameraPermissionState();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _cameraPermissionState = permissionState;
          _errorMessage = permissionState == CameraPermissionState.permanentlyDenied
              ? '相机权限未开启'
              : '需要相机权限才能拍摄';
        });
      }
    } on CameraInitException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '相机启动失败，请重试';
        });
      }
      debugPrint('CameraInitException: ${e.message}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '相机启动失败，请重试';
        });
      }
      debugPrint('Camera init error: $e');
    }
  }

  void _togglePopup(CameraPopupType type) {
    setState(() {
      _activePopup = _activePopup == type ? CameraPopupType.none : type;
    });
  }

  void _onToolbarSlot(CameraToolbarSlot slot) {
    final popup = popupForSlot(slot);
    if (popup != null) {
      _togglePopup(popup);
      return;
    }
    if (slot == CameraToolbarSlot.flash) {
      _cycleFlash();
    }
  }

  void _closePopup() {
    if (_activePopup != CameraPopupType.none) {
      setState(() => _activePopup = CameraPopupType.none);
    }
  }

  String get _flashIconPath {
    switch (_flashState) {
      case FlashToolbarState.off:
        return AppImages.flashOff;
      case FlashToolbarState.on:
        return AppImages.flashOn;
      case FlashToolbarState.auto:
        return AppImages.flashAuto;
    }
  }

  Future<void> _applyFlashState(FlashToolbarState state) async {
    await _cameraService.applyToolbarFlash(state);
  }

  Future<void> _cycleFlash() async {
    if (!_cameraService.isInitialized) return;
    if (!_cameraService.isBackCamera) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('前置摄像头不支持闪光灯'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    final next = _flashState.next;
    await _applyFlashState(next);
    if (!mounted) return;
    setState(() => _flashState = next);
  }

  Future<void> _flipCamera() async {
    if (!_cameraService.isInitialized) return;
    try {
      await _cameraService.switchCamera();
      _currentZoom = _cameraService.baselineOneX;
      if (_cameraService.isBackCamera) {
        await _applyFlashState(_flashState);
      } else {
        await _applyFlashState(FlashToolbarState.off);
        if (mounted) setState(() => _flashState = FlashToolbarState.off);
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('switchCamera error: $e');
    }
  }

  Future<void> _onZoomChanged(double zoom) async {
    if (zoom == _currentZoom) return;
    setState(() => _currentZoom = zoom);
    await _cameraService.setZoomLevel(zoom);
  }

  Future<void> _onShutter() async {
    if (!_cameraService.isInitialized || _isCapturing || _countdown != null) {
      return;
    }
    if (!_isPhotoMode) return;

    final burstCount = _burst.count;
    final mq = MediaQuery.of(context);
    final previewSize = _previewAreaSize(mq);
    final cropContext = _CaptureCropContext(
      aspectOption: _aspectRatio,
      screenSize: previewSize,
      previewAspect: _cameraService.previewAspectRatio,
      frameAlignY: _previewVerticalAlignY,
      fitContain: _aspectRatio.usesNativeSensorOutput,
      fullScreenPreview: _aspectRatio.usesFullScreenPreview,
      mirrorFront: !_cameraService.isBackCamera,
    );

    setState(() {
      _isCapturing = true;
    });

    try {
      if (_timer.seconds > 0) {
        for (var s = _timer.seconds; s >= 1; s--) {
          if (!mounted) return;
          setState(() => _countdown = s);
          await Future.delayed(const Duration(seconds: 1));
        }
        if (mounted) setState(() => _countdown = null);
      }

      final sessionSoundEffectId =
          SidebarSoundStore.instance.activeSoundEffectId;

      for (var i = 0; i < burstCount; i++) {
        if (mounted) {
          setState(() => _isGalleryLoading = true);
        }
        if (mounted) _playCaptureFlash();

        final reserved = _photoGallery.takeReadyCaptureSlot() ??
            await _photoGallery.acquireCaptureSlot();
        final capture = await _cameraService.takePicture(
          toolbarFlash: _flashState,
          crop: cropContext.toNativeMap(
            outputPath: reserved.path,
            playShutter: _shutterSoundEnabled,
          ),
        );
        if (capture != null) {
          Uint8List? thumbBytes = capture.thumbnailBytes;
          final thumbPath = capture.thumbnailPath;
          if (thumbBytes == null && thumbPath != null) {
            try {
              thumbBytes = await File(thumbPath).readAsBytes();
            } catch (e) {
              debugPrint('read gallery thumb failed: $e');
            }
          }
          if (mounted) {
            setState(() => _isGalleryLoading = false);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _galleryThumbBytes = thumbBytes;
                _applyCaptureGalleryThumb(
                  capture.fullPath,
                  thumbnailPath: thumbPath,
                );
              });
            });
          }

          // 与 Android 一致：缩略图先出图，登记/裁切/上传后台进行
          unawaited(
            _processCaptureAfterShutter(
              capturePath: capture.fullPath,
              cropContext: cropContext,
              reserved: reserved,
              soundEffectId: sessionSoundEffectId,
            ).then((ok) {
              if (!mounted || !ok) return;
              final latest = _photoGallery.latestPhoto;
              if (latest?.remoteUrl == null) return;
              setState(() => _galleryThumbRemoteUrl = latest!.remoteUrl);
            }),
          );
        } else if (mounted) {
          setState(() => _isGalleryLoading = false);
        }
        if (i < burstCount - 1) {
          await Future.delayed(const Duration(milliseconds: 350));
        }
      }
      await SidebarSoundStore.instance.stop();
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _countdown = null;
        });
      }
    }
  }

  void _playCaptureFlash() {
    setState(() => _flashOpacity = AppSizes.captureFlashOpacity);
    Future.delayed(
      const Duration(milliseconds: AppSizes.captureFlashHoldMs),
      () {
        if (mounted) setState(() => _flashOpacity = 0);
      },
    );
  }

  Future<bool> _processCaptureAfterShutter({
    required String capturePath,
    required _CaptureCropContext cropContext,
    required ({String id, String path}) reserved,
    int? soundEffectId,
  }) async {
    var localPath = capturePath;

    if (cropContext.aspectOption.usesNativeSensorOutput) {
      if (!Platform.isIOS) {
        await PhotoCropService.cropToPreviewFrame(
          sourcePath: localPath,
          aspectOption: cropContext.aspectOption,
          screenSize: cropContext.screenSize,
          previewAspect: cropContext.previewAspect,
          frameAlignY: cropContext.frameAlignY,
          fitContain: cropContext.fitContain,
          fullScreenPreview: cropContext.fullScreenPreview,
          mirrorFront: cropContext.mirrorFront,
        );
      }
    } else if (Platform.isIOS) {
      await PhotoCropService.cropToPreviewFrame(
        sourcePath: localPath,
        aspectOption: cropContext.aspectOption,
        screenSize: cropContext.screenSize,
        previewAspect: cropContext.previewAspect,
        frameAlignY: cropContext.frameAlignY,
        fitContain: cropContext.fitContain,
        fullScreenPreview: cropContext.fullScreenPreview,
        mirrorFront: cropContext.mirrorFront,
      );
    }

    if (localPath != reserved.path) {
      final moved = await _moveCaptureToReserved(localPath, reserved.path);
      if (!moved) return false;
      localPath = reserved.path;
    }

    await _photoGallery.registerCapture(
      id: reserved.id,
      localPath: localPath,
      soundEffectId: soundEffectId,
      upload: false,
      syncToGallery: false,
    );

    unawaited(_photoGallery.syncToSystemGallery(reserved.id));
    return await _photoGallery.uploadRecordForPhoto(
      reserved.id,
      soundEffectId: soundEffectId,
    );
  }

  Future<bool> _moveCaptureToReserved(String sourcePath, String destPath) async {
    try {
      final source = File(sourcePath);
      if (!await source.exists()) return false;
      final dest = File(destPath);
      await dest.parent.create(recursive: true);
      if (sourcePath == destPath) return true;
      try {
        await source.rename(destPath);
      } catch (_) {
        await source.copy(destPath);
        await source.delete();
      }
      return true;
    } catch (e) {
      debugPrint('_moveCaptureToReserved failed: $e');
      return false;
    }
  }

  bool get _shutterSoundEnabled => _settings.shutterSoundEnabled;

  void _openSettings() {
    _closePopup();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SettingsScreen(settings: _settings),
    );
  }

  void _openSoundLibrary() {
    _closePopup();
    SidebarSoundStore.instance.stop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SoundLibraryScreen(),
    ).whenComplete(_refreshSidebarEffects);
  }

  Future<void> _refreshSidebarEffects() async {
    final languageId = AppCacheStore.instance.defaultLanguageId;
    await CameraSoundStore.instance.refreshSidebarEffects(
      languageId: languageId,
    );
  }

  Future<void> _resumeCameraAfterOverlay() async {
    if (!_cameraService.isInitialized) {
      await _initCamera();
      return;
    }
    await _cameraService.resume();
    await _cameraService.setZoomLevel(_currentZoom);
    await _applyFlashState(_flashState);
    await _syncPreviewModeForAspect();
  }

  Future<void> _openPhotoGallery() async {
    _closePopup();
    if (!await _photoGallery.ensurePermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要相册权限才能查看和保存照片')),
        );
      }
      return;
    }
    if (!mounted) return;

    final router = GoRouter.of(context);
    final shouldResumeCamera =
        _cameraService.isInitialized && !_lifecyclePaused;
    if (shouldResumeCamera) {
      await _cameraService.pause();
    }

    try {
      await router.push<void>(AppRoutes.gallery);
    } finally {
      if (mounted && shouldResumeCamera) {
        await _resumeCameraAfterOverlay();
      }
    }

    if (mounted) {
      setState(() => _syncGalleryThumbFromLatest(preferCloud: false));
    }
  }

  Future<void> _requestCameraPermission() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final granted = await _cameraService.requestCameraPermission();
    if (granted) {
      await _initCamera();
      return;
    }

    final permissionState = await _cameraService.getCameraPermissionState();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _cameraPermissionState = permissionState;
        _errorMessage = permissionState == CameraPermissionState.permanentlyDenied
            ? '相机权限未开启，请在系统设置中允许'
            : '需要相机权限才能拍摄';
      });
    }
  }

  Widget _buildPreviewArea(BuildContext context) {
    if (_errorMessage != null) {
      return _buildPlaceholder(
        message: _errorMessage!,
        showPermissionActions: _cameraPermissionState != null,
      );
    }
    if (_isLoading || !_cameraService.isInitialized) {
      return _buildPlaceholder(message: '正在启动相机...');
    }

    final preview = CameraPreviewView(
      key: const ValueKey('camera_preview_view'),
      maskRatio: _aspectRatio.usesPreviewMask ? _aspectRatio.ratio : null,
      verticalAlignY: _previewVerticalAlignY,
    );
    return preview;
  }

  Widget _buildPlaceholder({
    required String message,
    bool showPermissionActions = false,
  }) {
    final needsSettings =
        _cameraPermissionState == CameraPermissionState.permanentlyDenied;

    return Container(
      color: AppColors.bottomBarBg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/camera/image_1.png', width: 64, height: 64),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textHint,
              ),
            ),
            if (showPermissionActions) ...[
              const SizedBox(height: 20),
              if (!needsSettings)
                FilledButton(
                  onPressed: _requestCameraPermission,
                  child: const Text('允许访问相机'),
                ),
              if (needsSettings) ...[
                OutlinedButton(
                  onPressed: _cameraService.openCameraSettings,
                  child: const Text('前往系统设置'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _initCamera,
                  child: const Text('我已开启，重试'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget? _buildActivePopup() {
    switch (_activePopup) {
      case CameraPopupType.aspectRatio:
        return AspectRatioPopup(
          selectedIndex: _aspectRatioIndex,
          onSelected: (i) {
            if (i == _aspectRatioIndex) return;
            setState(() => _aspectRatioIndex = i);
            unawaited(_syncPreviewModeForAspect());
          },
          onClose: _closePopup,
        );
      case CameraPopupType.burst:
        return BurstModePopup(
          selectedIndex: _settings.burstIndex,
          onSelected: _settings.setBurstIndex,
          onClose: _closePopup,
        );
      case CameraPopupType.timer:
        return TimerPopup(
          selectedIndex: _settings.timerIndex,
          onSelected: _settings.setTimerIndex,
          onClose: _closePopup,
        );
      case CameraPopupType.none:
        return null;
    }
  }

  Widget _buildTopBar() {
    return CameraTopBar(
      aspectRatioLabel: _aspectRatio.label,
      flashIconPath: _flashIconPath,
      burstBadge: _burst.count > 1 ? '${_burst.count}' : null,
      timerBadge: _timer.seconds > 0 ? '${_timer.seconds}s' : null,
      onSettings: _openSettings,
      onAspectRatio: () => _onToolbarSlot(CameraToolbarSlot.aspectRatio),
      onBurst: () => _onToolbarSlot(CameraToolbarSlot.burst),
      onTimer: () => _onToolbarSlot(CameraToolbarSlot.timer),
      onFlash: () => _onToolbarSlot(CameraToolbarSlot.flash),
    );
  }

  Widget _buildBottomBar({bool transparentBackground = false}) {
    return CameraBottomBar(
      isPhotoMode: _isPhotoMode,
      galleryThumbLocalPath: _galleryThumbLocalPath,
      galleryThumbRemoteUrl: _galleryThumbRemoteUrl,
      galleryThumbBytes: _galleryThumbBytes,
      galleryThumbPreferCloud: _galleryThumbPreferCloud,
      lastPhotoRevision: _lastPhotoRevision,
      isGalleryLoading: _isGalleryLoading,
      transparentBackground: transparentBackground,
      onShutter: _onShutter,
      onGallery: _openPhotoGallery,
      onFlipCamera: _flipCamera,
      onModeChanged: (photo) => setState(() => _isPhotoMode = photo),
    );
  }

  Widget _buildPreviewOverlays() {
    return Stack(
      fit: StackFit.expand,
      children: [
        CaptureShutterOverlay(flashOpacity: _flashOpacity),
        if (_countdown != null) CountdownOverlay(seconds: _countdown!),
        if (_cameraService.isInitialized && !_isLoading) ...[
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSizes.zoomBarBottom,
            child: Center(
              child: ZoomControl(
                currentZoom: _currentZoom,
                baselineOneX: _cameraService.baselineOneX,
                onZoomChanged: _onZoomChanged,
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: ListenableBuilder(
                listenable: SidebarSoundStore.instance,
                builder: (context, _) {
                  final store = SidebarSoundStore.instance;
                  return PetEmojiMenu(
                    slots: store.slots,
                    onTap: store.toggle,
                    onMoreSounds: _openSoundLibrary,
                  );
                },
              ),
            ),
          ),
        ],
        if (_activePopup != CameraPopupType.none)
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: _buildActivePopup()!,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullScreenPreview = _aspectRatio.usesFullScreenPreview;
    return Scaffold(
      backgroundColor: AppColors.cameraBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _buildPreviewArea(context)),
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: _buildTopBar(),
              ),
              Expanded(child: _buildPreviewOverlays()),
              SafeArea(
                top: false,
                child: _buildBottomBar(
                  transparentBackground: fullScreenPreview,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CaptureCropContext {
  final AspectRatioOption aspectOption;
  final Size screenSize;
  final double previewAspect;
  final double frameAlignY;
  final bool fitContain;
  final bool fullScreenPreview;
  final bool mirrorFront;

  const _CaptureCropContext({
    required this.aspectOption,
    required this.screenSize,
    required this.previewAspect,
    required this.frameAlignY,
    required this.fitContain,
    required this.fullScreenPreview,
    this.mirrorFront = false,
  });

  /// 全屏模式裁成屏幕比例（与预览 WYSIWYG）；其余模式用选项比例
  double get _outputCropRatio => fullScreenPreview
      ? screenSize.width / screenSize.height
      : aspectOption.ratio;

  Map<String, dynamic> toNativeMap({
    String? outputPath,
    bool playShutter = false,
  }) =>
      {
        'ratio': _outputCropRatio,
        'screenWidth': screenSize.width,
        'screenHeight': screenSize.height,
        'topInset': 0,
        'bottomInset': 0,
        'frameAlignY': frameAlignY,
        'previewAspect': previewAspect,
        'fitContain': fitContain,
        'fullScreenPreview': fullScreenPreview,
        'fullScreen': !aspectOption.usesPreviewMask,
        'nativeSensor': aspectOption.usesNativeSensorOutput,
        'directOutput': aspectOption.usesNativeSensorOutput,
        'mirrorFront': mirrorFront,
        'outputPath': ?outputPath,
        if (playShutter) 'playShutter': true,
      };
}
