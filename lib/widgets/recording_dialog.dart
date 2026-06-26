import 'dart:async';

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../constants/app_sizes.dart';
import '../data/camera_sound_store.dart';
import '../services/sound_recording_service.dart';
import 'toast_message.dart';

/// 录制自定义音效对话框
class RecordingDialog extends StatefulWidget {
  final ValueChanged<String>? onConfirm;
  final VoidCallback? onCancel;

  const RecordingDialog({super.key, this.onConfirm, this.onCancel});

  @override
  State<RecordingDialog> createState() => _RecordingDialogState();
}

class _RecordingDialogState extends State<RecordingDialog> {
  final _controller = TextEditingController();
  final _recordingService = SoundRecordingService();

  bool _isRecording = false;
  bool _hasRecorded = false;
  bool _isSaving = false;
  double _progress = 0;
  Timer? _progressTimer;
  DateTime? _recordingStartedAt;

  static const _inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: AppColors.inputBorder, width: 1),
  );

  bool get _hasName => _controller.text.trim().isNotEmpty;

  bool get _isRedStyle => _isRecording;

  Color get _startBtnBg =>
      _isRedStyle ? AppColors.recordRed : AppColors.primary;

  Color get _startBtnText => AppColors.textOnDark;

  Color get _secondaryBtnColor =>
      _isRedStyle ? AppColors.recordRed : AppColors.primary;

  String get _startBtnLabel {
    if (_isRecording) return '结束录制';
    if (_hasRecorded) return '重新录制';
    return '开始录制';
  }

  String get _secondaryBtnLabel {
    if (_isSaving) return '上传中...';
    return _hasRecorded ? '保存' : '取消';
  }

  int get _elapsedSeconds {
    if (_recordingStartedAt == null) {
      return (_progress * SoundRecordingService.maxDuration.inSeconds).round();
    }
    return DateTime.now().difference(_recordingStartedAt!).inSeconds;
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _recordingStartedAt = null;
  }

  Future<void> _startRecording() async {
    if (!_hasName) {
      ToastMessage.show(context, '请先输入音效名称');
      return;
    }

    final granted = await _recordingService.ensurePermission();
    if (!granted) {
      if (mounted) {
        ToastMessage.show(context, '需要麦克风权限才能录制音效');
      }
      return;
    }

    if (_hasRecorded) {
      await _recordingService.clearRecording();
    }

    try {
      await _recordingService.start();
    } catch (_) {
      if (mounted) {
        ToastMessage.show(context, '录音启动失败，请重试');
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _hasRecorded = false;
      _progress = 0;
    });
    widget.onConfirm?.call(_controller.text.trim());

    _recordingStartedAt = DateTime.now();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || _recordingStartedAt == null) return;
      final elapsed = DateTime.now().difference(_recordingStartedAt!);
      final progress = elapsed.inMilliseconds /
          SoundRecordingService.maxDuration.inMilliseconds;
      if (progress >= 1.0) {
        _finishRecording();
      } else {
        setState(() => _progress = progress);
      }
    });
  }

  Future<void> _finishRecording() async {
    if (!_isRecording) return;
    _stopProgressTimer();
    await _recordingService.stop();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _hasRecorded = true;
      _progress = 1;
    });
  }

  Future<void> _cancelRecording() async {
    _stopProgressTimer();
    await _recordingService.cancel();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _hasRecorded = false;
      _progress = 0;
    });
  }

  void _onStartTap() {
    if (_isRecording) {
      _finishRecording();
      return;
    }
    _startRecording();
  }

  Future<void> _onSaveTap() async {
    if (_isSaving) return;
    final path = _recordingService.filePath;
    final name = _controller.text.trim();
    if (path == null || name.isEmpty) return;

    setState(() => _isSaving = true);
    final result = await CameraSoundStore.instance.addCustomSoundEffect(
      name: name,
      localPath: path,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result.ok) {
      Navigator.of(context).pop();
    }
    if (result.msg.isNotEmpty) {
      ToastMessage.show(context, result.msg);
    }
  }

  void _onSecondaryTap() {
    if (_isRecording) {
      _cancelRecording();
      return;
    }
    if (_hasRecorded) {
      _onSaveTap();
      return;
    }
    widget.onCancel?.call();
  }

  Future<void> _playPreview() async {
    if (!_hasRecorded) return;
    await _recordingService.playPreview();
  }

  @override
  void dispose() {
    _stopProgressTimer();
    _recordingService.dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildHintSection() {
    if (_isRecording) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 6,
              backgroundColor: AppColors.inputBorder,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.recordRed),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_elapsedSeconds.clamp(0, 15)}s / 15s',
            style: const TextStyle(
              fontSize: AppSizes.dialogHintFontSize,
              color: AppColors.textGray,
            ),
          ),
        ],
      );
    }

    if (_hasRecorded) {
      return GestureDetector(
        onTap: _playPreview,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '已录制的录音音频试听',
              style: TextStyle(
                fontSize: AppSizes.dialogHintFontSize,
                color: AppColors.textGray,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.play_circle_outline,
              size: 20,
              color: AppColors.primary,
            ),
          ],
        ),
      );
    }

    return const Text(
      '点击下方按钮开始录制',
      style: TextStyle(
        fontSize: AppSizes.dialogHintFontSize,
        color: AppColors.textGray,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: AppColors.overlayDialog,
        child: Center(
          child: Container(
            width: AppSizes.dialogWidth,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.fromLTRB(
              AppSizes.dialogPaddingH,
              AppSizes.dialogPaddingTop,
              AppSizes.dialogPaddingH,
              AppSizes.dialogPaddingBottom,
            ),
            decoration: BoxDecoration(
              color: AppColors.dialogBg,
              borderRadius: BorderRadius.circular(AppSizes.dialogRadius),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  offset: Offset(0, 12),
                  blurRadius: 40,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      AppImages.micIcon,
                      width: 14,
                      height: 14,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '录制自定义音效',
                      style: TextStyle(
                        fontSize: AppSizes.dialogTitleSize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dialogTitle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: AppSizes.dialogInputHeight,
                  child: TextField(
                    controller: _controller,
                    enabled: !_isRecording && !_isSaving,
                    cursorColor: AppColors.textHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: AppSizes.dialogFontSize,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '输入音效名称（如：叫咪咪）',
                      hintStyle: const TextStyle(
                        fontSize: AppSizes.dialogFontSize,
                        color: AppColors.textHint,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: _inputBorder,
                      enabledBorder: _inputBorder,
                      focusedBorder: _inputBorder,
                      disabledBorder: _inputBorder,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildHintSection(),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _isSaving ? null : _onStartTap,
                        child: Container(
                          height: AppSizes.dialogBtnHeight,
                          decoration: BoxDecoration(
                            color: _startBtnBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                AppImages.micIcon,
                                width: 14,
                                height: 14,
                                color: _startBtnText,
                                colorBlendMode: BlendMode.srcIn,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _startBtnLabel,
                                style: TextStyle(
                                  fontSize: AppSizes.dialogFontSize,
                                  fontWeight: FontWeight.w600,
                                  color: _startBtnText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: _isSaving ? null : _onSecondaryTap,
                        child: Container(
                          height: AppSizes.dialogBtnHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _secondaryBtnColor,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _secondaryBtnLabel,
                                    style: TextStyle(
                                      fontSize: AppSizes.dialogFontSize,
                                      fontWeight: FontWeight.w600,
                                      color: _secondaryBtnColor,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
