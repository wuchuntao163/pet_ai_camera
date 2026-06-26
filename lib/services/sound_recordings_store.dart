import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/recorded_sound.dart';

/// 我的录制音效本地存储（静态内存 + 文件，后续接入接口）
class SoundRecordingsStore extends ChangeNotifier {
  SoundRecordingsStore._();

  static final SoundRecordingsStore instance = SoundRecordingsStore._();

  final List<RecordedSound> _items = [];
  final AudioPlayer _player = AudioPlayer();

  List<RecordedSound> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  Future<void> add({required String name, required String sourcePath}) async {
    final dir = await getApplicationDocumentsDirectory();
    final soundsDir = Directory(p.join(dir.path, 'recorded_sounds'));
    if (!await soundsDir.exists()) {
      await soundsDir.create(recursive: true);
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final destPath = p.join(soundsDir.path, '$id.m4a');
    await File(sourcePath).copy(destPath);

    _items.insert(
      0,
      RecordedSound(
        id: id,
        name: name,
        filePath: destPath,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  Future<void> remove(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;

    final item = _items[index];
    final file = File(item.filePath);
    if (await file.exists()) {
      await file.delete();
    }
    _items.removeAt(index);
    notifyListeners();
  }

  Future<void> play(String filePath) async {
    await _player.stop();
    await _player.play(DeviceFileSource(filePath));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
