import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 音效库列表预览播放（循环）
class SoundLibraryPreviewService extends ChangeNotifier {
  SoundLibraryPreviewService._() {
    _player.onPlayerStateChanged.listen((state) {
      if (_playingKey == null) return;
      final playing = state == PlayerState.playing;
      if (_isPlaying != playing) {
        _isPlaying = playing;
        notifyListeners();
      }
    });
  }

  static final SoundLibraryPreviewService instance =
      SoundLibraryPreviewService._();

  final AudioPlayer _player = AudioPlayer();
  String? _playingKey;
  bool _isPlaying = false;

  String? get playingKey => _playingKey;

  bool isPlayingKey(String key) => _playingKey == key && _isPlaying;

  bool isPausedKey(String key) => _playingKey == key && !_isPlaying;

  static String effectKey(int effectId) => 'effect_$effectId';

  static String recordingKey(String id) => 'rec_$id';

  Future<void> toggleUrl({
    required String key,
    required String url,
  }) async {
    if (url.isEmpty) return;

    if (_playingKey == key) {
      if (_isPlaying) {
        await _player.pause();
        _isPlaying = false;
      } else {
        await _player.resume();
        _isPlaying = true;
      }
      notifyListeners();
      return;
    }

    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.loop);
    _playingKey = key;
    _isPlaying = true;
    notifyListeners();
    await _player.play(UrlSource(url));
  }

  Future<void> toggleFile({
    required String key,
    required String filePath,
  }) async {
    if (filePath.isEmpty) return;

    if (_playingKey == key) {
      if (_isPlaying) {
        await _player.pause();
        _isPlaying = false;
      } else {
        await _player.resume();
        _isPlaying = true;
      }
      notifyListeners();
      return;
    }

    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.loop);
    _playingKey = key;
    _isPlaying = true;
    notifyListeners();
    await _player.play(DeviceFileSource(filePath));
  }

  Future<void> stop() async {
    await _player.stop();
    _playingKey = null;
    _isPlaying = false;
    notifyListeners();
  }
}
