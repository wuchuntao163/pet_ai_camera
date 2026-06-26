import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../app/app_services.dart';
import '../constants/app_images.dart';
import '../data/camera_sound_store.dart';
import '../models/sidebar_sound_slot.dart';

/// 相机右侧音效按钮，数据来自 [CameraSoundStore.sidebarEffects]
class SidebarSoundStore extends ChangeNotifier {
  SidebarSoundStore._() {
    CameraSoundStore.instance.addListener(_syncFromApi);
    AppServices.instance.cameraSettings.addListener(_applyVolume);
    _applyVolume();
    _player.onPlayerStateChanged.listen((state) {
      if (_playingIndex == null) return;
      final playing = state == PlayerState.playing;
      if (_isPlaying != playing) {
        _isPlaying = playing;
        notifyListeners();
      }
    });
    _syncFromApi();
  }

  static final SidebarSoundStore instance = SidebarSoundStore._();

  final AudioPlayer _player = AudioPlayer();
  List<SidebarSoundSlot> _slots = [];
  int? _playingIndex;
  bool _isPlaying = false;

  List<SidebarSoundSlot> get slots => List.unmodifiable(_slots);

  int? get activeSoundEffectId {
    final index = _playingIndex;
    if (!_isPlaying || index == null) return null;
    if (index < 0 || index >= _slots.length) return null;
    final id = _slots[index].effectId;
    return id != null && id > 0 ? id : null;
  }

  Future<void> _applyVolume() async {
    await _player.setVolume(AppServices.instance.cameraSettings.petSoundVolume);
  }

  void _syncFromApi() {
    final effects = CameraSoundStore.instance.sidebarEffects;
    _slots = effects.map(_slotFromEffect).toList();
    if (_playingIndex != null && _playingIndex! >= _slots.length) {
      _playingIndex = null;
      _isPlaying = false;
      _player.stop();
    }
    notifyListeners();
  }

  SidebarSoundSlot _slotFromEffect(Map<String, dynamic> effect) {
    final imageUrl = effect['image_url']?.toString();
    final isCustom = _isCustomEffect(effect);
    return SidebarSoundSlot(
      emoji: '🔊',
      name: effect['name']?.toString() ?? '',
      soundUrl: effect['sound_url']?.toString(),
      effectId: _asInt(effect['id']),
      imageUrl: imageUrl != null && imageUrl.isNotEmpty ? imageUrl : null,
      leadingAsset: isCustom ? AppImages.microphone : null,
    );
  }

  bool _isCustomEffect(Map<String, dynamic> effect) {
    if (_asInt(effect['sound_type']) == 2) return true;
    final customCategoryId = CameraSoundStore.instance.customCategoryId;
    if (customCategoryId != null &&
        _asInt(effect['category_id']) == customCategoryId) {
      return true;
    }
    return false;
  }

  Future<void> toggle(int index) async {
    if (index < 0 || index >= _slots.length) return;
    final slot = _slots[index];

    if (_playingIndex == index) {
      if (_isPlaying) {
        await _player.pause();
        _isPlaying = false;
      } else {
        await _applyVolume();
        await _player.resume();
        _isPlaying = true;
      }
      notifyListeners();
      return;
    }

    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.loop);
    await _applyVolume();
    _playingIndex = index;
    _isPlaying = true;
    notifyListeners();

    if (slot.localPath != null && slot.localPath!.isNotEmpty) {
      await _player.play(DeviceFileSource(slot.localPath!));
      return;
    }

    final url = slot.soundUrl;
    if (url != null && url.isNotEmpty) {
      await _player.play(UrlSource(url));
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _playingIndex = null;
    _isPlaying = false;
    notifyListeners();
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
