import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../constants/app_sizes.dart';
import '../data/app_cache_store.dart';
import '../data/camera_sound_store.dart';
import '../models/sidebar_sound_slot.dart';
import '../services/sound_library_preview_service.dart';
import '../widgets/toast_message.dart';
import '../widgets/recording_dialog.dart';
import '../widgets/sound_card.dart';
import '../widgets/sound_library_tab_bar.dart';

/// 宠物音效库（底部弹窗）
class SoundLibraryScreen extends StatefulWidget {
  final int initialTab;
  final ValueChanged<SidebarSoundSlot>? onSoundPicked;

  const SoundLibraryScreen({
    super.key,
    this.initialTab = 1,
    this.onSoundPicked,
  });

  @override
  State<SoundLibraryScreen> createState() => _SoundLibraryScreenState();
}

class _SoundLibraryScreenState extends State<SoundLibraryScreen> {
  late int _selectedTab;
  final _soundStore = CameraSoundStore.instance;
  final _preview = SoundLibraryPreviewService.instance;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _preview.stop();
    super.dispose();
  }

  bool get _isPickerMode => widget.onSoundPicked != null;

  SoundLibraryTab _recordingsTabItem() {
    final custom = _soundStore.customCategory;
    return SoundLibraryTab(
      label: custom?['name']?.toString() ?? '我的录制',
      iconUrl: custom?['icon']?.toString(),
      emoji: '🎤',
      isRecordings: true,
    );
  }

  List<SoundLibraryTab> _buildTabs() {
    final categories = _soundStore.apiTabCategories;
    return [
      _recordingsTabItem(),
      ...categories.map(
        (item) => SoundLibraryTab(
          label: item['name']?.toString() ?? '音效',
          iconUrl: item['icon']?.toString(),
          categoryId: _asInt(item['id']),
        ),
      ),
    ];
  }

  SoundLibraryTab? _tabAt(int index, List<SoundLibraryTab> tabs) {
    if (index < 0 || index >= tabs.length) return null;
    return tabs[index];
  }

  Future<void> _loadData() async {
    final languageId = AppCacheStore.instance.defaultLanguageId;
    if (_soundStore.categories.isEmpty) {
      await _soundStore.fetchCategories(languageId: languageId);
    }
    if (_soundStore.allEffects.isEmpty) {
      await _soundStore.fetchAllEffects(languageId: languageId);
    }
    if (!mounted) return;
    final tabs = _buildTabs();
    if (_selectedTab >= tabs.length) {
      setState(() => _selectedTab = tabs.isEmpty ? 0 : 0);
    }
    await _loadEffectsForTab(_selectedTab, tabs);
  }

  Future<void> _loadEffectsForTab(int index, List<SoundLibraryTab> tabs) async {
    final tab = _tabAt(index, tabs);
    if (tab == null) return;

    final languageId = AppCacheStore.instance.defaultLanguageId;
    if (tab.isRecordings) {
      if (_soundStore.customEffects.isEmpty) {
        await _soundStore.fetchCustomEffects(languageId: languageId);
      }
      return;
    }

    final categoryId = tab.categoryId;
    if (categoryId == null || categoryId <= 0) return;

    final cached = _soundStore.effectsForCategory(categoryId);
    if (cached.isEmpty) {
      await _soundStore.fetchEffects(
        categoryId: categoryId,
        languageId: languageId,
      );
    }
  }

  void _onTabChanged(int index) {
    _preview.stop();
    setState(() => _selectedTab = index);
    _loadEffectsForTab(index, _buildTabs());
  }

  void _pickSound(SidebarSoundSlot slot) {
    widget.onSoundPicked?.call(slot);
    if (_isPickerMode && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _onEffectTap(Map<String, dynamic> effect, {String emoji = '🔊'}) {
    if (_isPickerMode) {
      _pickSound(
        SidebarSoundSlot(
          emoji: emoji,
          name: effect['name']?.toString() ?? '',
          soundUrl: effect['sound_url']?.toString(),
          imageUrl: effect['image_url']?.toString(),
          effectId: _asInt(effect['id']),
        ),
      );
      return;
    }
    _playEffect(effect);
  }

  Future<void> _playEffect(Map<String, dynamic> effect) async {
    final effectId = _asInt(effect['id']);
    final url = effect['sound_url']?.toString() ?? '';
    if (url.isEmpty) return;
    await _preview.toggleUrl(
      key: SoundLibraryPreviewService.effectKey(effectId),
      url: url,
    );
  }

  Future<void> _toggleSidebarEffect(Map<String, dynamic> effect) async {
    final result = await _soundStore.toggleSidebarEffect(effect);
    if (!mounted) return;
    if (!result.ok && result.msg.isNotEmpty) {
      ToastMessage.show(context, result.msg);
    }
  }

  Future<void> _deleteCustomEffect(Map<String, dynamic> effect) async {
    final effectId = _asInt(effect['id']);
    if (effectId <= 0) return;
    final result = await _soundStore.deleteCustomSoundEffect(effectId);
    if (!mounted) return;
    if (!result.ok && result.msg.isNotEmpty) {
      ToastMessage.show(context, result.msg);
    }
  }

  void _showRecordingDialog() {
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => RecordingDialog(
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    ).then((_) async {
      if (!mounted) return;
      await _soundStore.fetchCustomEffects(
        languageId: AppCacheStore.instance.defaultLanguageId,
      );
    });
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_soundStore, _preview]),
      builder: (context, _) {
        final tabs = _buildTabs();
        final safeIndex =
            tabs.isEmpty ? 0 : _selectedTab.clamp(0, tabs.length - 1);

        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: AppColors.soundLibraryBg,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppSizes.sheetRadius)),
            boxShadow: [
              BoxShadow(
                color: Color(0x40000000),
                offset: Offset(0, -25),
                blurRadius: 50,
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                child: Row(
                  children: [
                    const Text(
                      '宠物音效库',
                      style: TextStyle(
                        fontSize: AppSizes.soundSheetTitleSize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.soundTitle,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: AppSizes.soundCloseBtn,
                        height: AppSizes.soundCloseBtn,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/camera/image_19.png',
                            width: AppSizes.closeIcon,
                            height: AppSizes.closeIcon,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SoundLibraryTabBar(
                  tabs: tabs,
                  selectedIndex: safeIndex,
                  onTabChanged: _onTabChanged,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildTabBody(safeIndex, tabs)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBody(int index, List<SoundLibraryTab> tabs) {
    final tab = _tabAt(index, tabs);
    if (tab == null) {
      return _buildCategoriesLoading();
    }
    if (tab.isRecordings) {
      return _buildRecordingsTab();
    }
    return _buildCategoryEffectsTab(tab);
  }

  Widget _buildCategoriesLoading() {
    if (_soundStore.categoriesLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return const Center(
      child: Text(
        '暂无音效分类',
        style: TextStyle(color: AppColors.textHint, fontSize: 14),
      ),
    );
  }

  Widget _buildEffectCard(
    Map<String, dynamic> effect, {
    String emoji = '🔊',
    String? leadingAsset,
    VoidCallback? onDelete,
  }) {
    final name = effect['name']?.toString() ?? '';
    final imageUrl = effect['image_url']?.toString();
    final effectId = _asInt(effect['id']);
    final isAdded = _soundStore.isUserAdded(effect);
    final playKey = SoundLibraryPreviewService.effectKey(effectId);
    return SoundCard(
      emoji: emoji,
      name: name,
      imageUrl: imageUrl,
      leadingAsset: leadingAsset,
      isAdded: isAdded,
      isPlaying: _preview.isPlayingKey(playKey),
      isToggling: _soundStore.isEffectToggling(effectId),
      onPlayPause: () => _onEffectTap(effect, emoji: emoji),
      onToggleAdd: _isPickerMode ? null : () => _toggleSidebarEffect(effect),
      onDelete: onDelete,
    );
  }

  Widget _buildCategoryEffectsTab(SoundLibraryTab tab) {
    final categoryId = tab.categoryId;
    if (categoryId == null) return const SizedBox.shrink();

    final effects = _soundStore.effectsForCategory(categoryId);
    if (_soundStore.effectsLoading && effects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (effects.isEmpty) {
      return const Center(
        child: Text(
          '该分类暂无音效',
          style: TextStyle(color: AppColors.textHint, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      itemCount: effects.length,
      itemBuilder: (_, i) => _buildEffectCard(effects[i]),
    );
  }

  Widget _buildRecordingsTab() {
    final effects = _soundStore.customEffects;
    if (_soundStore.customLoading && effects.isEmpty) {
      return Column(
        children: [
          _buildRecordButton(),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    return Column(
      children: [
        _buildRecordButton(),
        const SizedBox(height: 12),
        Expanded(
          child: effects.isEmpty
              ? _buildEmptyRecordings()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                  itemCount: effects.length,
                  itemBuilder: (_, i) {
                    final effect = effects[i];
                    return _buildEffectCard(
                      effect,
                      leadingAsset: AppImages.microphone,
                      onDelete: _isPickerMode
                          ? null
                          : () => _deleteCustomEffect(effect),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRecordButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: GestureDetector(
        onTap: _showRecordingDialog,
        child: Container(
          height: AppSizes.soundRecordBtnHeight,
          decoration: BoxDecoration(
            color: AppColors.myRecordingBg,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: AppSizes.soundRecordBtnIconBox,
                height: AppSizes.soundRecordBtnIconBox,
                decoration: BoxDecoration(
                  color: const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(
                    AppSizes.soundRecordBtnIconBox / 2,
                  ),
                ),
                child: Center(
                  child: Image.asset(
                    AppImages.micIcon,
                    width: AppSizes.soundRecordBtnIcon,
                    height: AppSizes.soundRecordBtnIcon,
                    color: AppColors.textOnDark,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '录制新音效',
                style: TextStyle(
                  fontSize: AppSizes.soundRecordBtnFontSize,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOnDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyRecordings() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          AppImages.emptyState,
          width: AppSizes.soundEmptyStateIcon,
          height: AppSizes.soundEmptyStateIcon,
          color: AppColors.textHint.withValues(alpha: 0.25),
          colorBlendMode: BlendMode.srcIn,
        ),
        const SizedBox(height: 12),
        const Text(
          '还没有录制音效',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textGray,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '点击上方按钮开始录制',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }
}
