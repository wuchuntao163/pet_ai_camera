import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// 自定义音效录制与试听（最长 15 秒）
class SoundRecordingService {
  static const Duration maxDuration = Duration(seconds: 15);

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  String? _filePath;
  bool _previewPlaying = false;
  final StreamController<bool> _previewPlayingController =
      StreamController<bool>.broadcast();

  SoundRecordingService() {
    _player.onPlayerStateChanged.listen((state) {
      final playing = state == PlayerState.playing;
      if (_previewPlaying == playing) return;
      _previewPlaying = playing;
      _previewPlayingController.add(playing);
    });
  }

  String? get filePath => _filePath;

  bool get isPreviewPlaying => _previewPlaying;

  Stream<bool> get previewPlayingStream => _previewPlayingController.stream;

  Future<bool> ensurePermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;
    status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> start() async {
    await stopPlayback();
    final dir = await getTemporaryDirectory();
    _filePath = p.join(
      dir.path,
      'pet_sound_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _filePath!,
    );
  }

  Future<String?> stop() async {
    final path = await _recorder.stop();
    _filePath = path ?? _filePath;
    return _filePath;
  }

  Future<void> cancel() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    await _deleteFile();
    _filePath = null;
  }

  Future<void> _deleteFile() async {
    final path = _filePath;
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> clearRecording() async {
    await stopPlayback();
    await cancel();
  }

  Future<void> playPreview() => togglePreview();

  Future<void> togglePreview() async {
    final path = _filePath;
    if (path == null || !await File(path).exists()) return;

    if (_player.state == PlayerState.playing) {
      await _player.pause();
      return;
    }
    if (_player.state == PlayerState.paused) {
      await _player.resume();
      return;
    }
    await _player.play(DeviceFileSource(path));
  }

  Future<void> stopPlayback() async {
    await _player.stop();
    _previewPlaying = false;
    _previewPlayingController.add(false);
  }

  Future<void> dispose() async {
    await stopPlayback();
    await cancel();
    await _recorder.dispose();
    await _player.dispose();
    await _previewPlayingController.close();
  }
}
