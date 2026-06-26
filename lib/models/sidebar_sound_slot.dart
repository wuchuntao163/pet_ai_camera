/// 相机右侧侧边栏音效槽位
class SidebarSoundSlot {
  final String emoji;
  final String name;
  final String? soundUrl;
  final String? localPath;
  final String? imageUrl;
  final String? leadingAsset;
  final int? effectId;

  const SidebarSoundSlot({
    required this.emoji,
    required this.name,
    this.soundUrl,
    this.localPath,
    this.imageUrl,
    this.leadingAsset,
    this.effectId,
  });

  SidebarSoundSlot copyWith({
    String? emoji,
    String? name,
    String? soundUrl,
    String? localPath,
    String? imageUrl,
    String? leadingAsset,
    int? effectId,
  }) {
    return SidebarSoundSlot(
      emoji: emoji ?? this.emoji,
      name: name ?? this.name,
      soundUrl: soundUrl ?? this.soundUrl,
      localPath: localPath ?? this.localPath,
      imageUrl: imageUrl ?? this.imageUrl,
      leadingAsset: leadingAsset ?? this.leadingAsset,
      effectId: effectId ?? this.effectId,
    );
  }
}
