/// UI 尺寸常量（按设计稿）
library;

class AppSizes {
  AppSizes._();

  // --- 相机 ---
  static const double topBarHeight = 72;
  static const double toolbarBtn = 40;

  static const double toolbarIcon = 22;

  /// 顶部工具栏各图标尺寸（可单独调整）
  static const double toolbarSettingsIcon = toolbarIcon;
  static const double toolbarBurstIcon = toolbarIcon;
  static const double toolbarTimerIcon = 21;
  static const double toolbarFlashIcon = 25;
  static const double toolbarGap = 8;
  static const double shutterOuter = 68;
  static const double shutterInner = 56;
  static const double shutterBorder = 3;
  static const double galleryThumb = 45;
  static const double flipBtn = 48;

  // --- 相机右侧音效栏 ---
  /// 音效槽位 / 「更多音效」圆形按钮直径
  static const double petMenuBtn = 54;

  /// 收起、展开（提醒）圆形按钮直径
  static const double petMenuToggleBtn = 46;

  /// 槽位内音效封面图 / emoji 字号（网络图宽高 = 本值 + 4）
  static const double petMenuEmoji = 20;

  /// 收起箭头图标宽高
  static const double petMenuCollapseIcon = 14;

  /// 收起态「提醒」入口图片宽高
  static const double petMenuRemindIcon = 20;

  /// 「更多音效」入口图片宽高
  static const double petMenuMoreIcon = 22;

  /// 槽位圆内音效名称字号
  static const double petMenuCircleFontSize = 9;

  /// 圆内名称最大宽度（保证 5 个字不超出圆形边界）
  static const double petMenuTextMaxWidth = petMenuBtn - 14;

  /// 槽位内封面图与名称之间的间距
  static const double petMenuCircleContentGap = 2;

  /// 名称相对封面图的垂直偏移（0 表示不偏移）
  static const double petMenuCircleTextShiftUp = 0;

  /// 相邻槽位 / 槽位与收起按钮之间的间距
  static const double petMenuItemGap = 8;

  /// 列表底部露出下一项的高度（提示可滑动）
  static const double petMenuScrollPeek = 22;

  /// 展开态列表区域最大高度（4 个槽位 + 间距 + 底部露出）
  static const double petMenuScrollHeight =
      petMenuBtn * 4 + petMenuItemGap * 3 + petMenuScrollPeek;

  static const double aspectRatioFontSize = 13;
  static const double zoomFontSize = 11;
  static const double zoomSegmentItemHeight = 35;
  static const double zoomSegmentPaddingH = 0;
  static const double zoomSegmentPaddingV = 2;
  static const double modeSegmentFontSize = 13;

  /// 照片/视频切换条整体上移（像素）
  static const double modeSegmentShiftUp = 8;

  /// 底部栏占位（模式切换 + 快门行 + 内边距），用于比例取景框上移
  /// iOS 全屏叠层布局仍用此固定值；Android 请用 [cameraBottomBarContentHeight]
  static const double cameraBottomChrome = 172;

  /// 底栏内容高度（与 [CameraBottomBar] 一致，不含 SafeArea）
  static const double cameraBottomBarContentHeight =
      8 + zoomSegmentItemHeight + 16 + shutterOuter + 48;

  /// 预览与取景框垂直位置（0=顶，0.5=居中；仅 9:16 全屏除外）
  /// Android 标准布局在代码中改为底部对齐（1.0），此值主要给 iOS 遮罩比例用
  static const double previewVerticalAlignY = 0.35;

  /// iOS 3:4 在预览区内垂直位置（0=靠顶；Android 为 0.35，iOS 需更靠上）
  static const double ios34PreviewAlignY = 0.0;

  /// 1X/2X/5X 距预览区底部的距离
  static const double zoomBarBottom = 10;

  /// iOS：1X/2X/5X 距预览区底部（略低于 Android）
  static const double iosZoomBarBottom = 0;

  /// iOS：照片切换条下移（正值=靠下）
  static const double iosModeSegmentShiftDown = 8;

  /// 快门闪白：亮度与停留时间
  static const double captureFlashOpacity = 0.22;
  static const int captureFlashHoldMs = 14;

  // --- 底部弹窗 ---
  static const double sheetRadius = 20;
  static const double sheetHeaderHeight = 64;
  static const double sheetTitleSize = 20;
  static const double sheetPaddingH = 20;

  /// 设置面板高度（相对屏幕）
  static const double settingsSheetHeightFactor = 0.65;
  static const double closeBtn = 32;
  static const double closeIcon = 10;

  // --- 设置卡片 ---
  static const double cardRadius = 16;
  static const double cardPadding = 16;
  static const double cardGap = 12;
  static const double settingIcon = 20;
  static const double bodyFontSize = 14;
  static const double subtitleFontSize = 12;

  // --- 音效库弹窗 ---
  /// 弹窗标题「宠物音效库」字号
  static const double soundSheetTitleSize = 17;

  /// 弹窗右上角关闭按钮宽高
  static const double soundCloseBtn = 28;

  // --- 音效库 Tab 栏（我的录制 / 分类） ---
  /// Tab 条内容区高度（实际外层 +8 留白）
  static const double soundTabHeight = 44;

  /// Tab 标签文字字号
  static const double soundTabFontSize = 14;

  /// Tab 分类图标 / emoji 字号（网络图宽高 = 本值 + 2）
  static const double soundTabEmojiSize = 15;

  // --- 音效库「录制新音效」按钮 ---
  /// 按钮高度
  static const double soundRecordBtnHeight = 56;

  /// 按钮文字字号
  static const double soundRecordBtnFontSize = 15;

  /// 按钮左侧麦克风图标容器宽高
  static const double soundRecordBtnIconBox = 32;

  /// 按钮左侧麦克风图标宽高
  static const double soundRecordBtnIcon = 18;

  // --- 音效库列表卡片（分类音效 / 我的录制） ---
  /// 卡片高度
  static const double soundCardHeight = 84;

  /// 卡片左侧封面图 / emoji 字号
  static const double soundCardEmoji = 36;

  /// 卡片右侧操作图标字号（播放/暂停、加/勾）
  static const double soundCardActionIcon = 32;

  /// 卡片右侧 PNG 操作图标（删除等，与圆形图标视觉对齐）
  static const double soundCardAssetActionIcon = 22;

  /// 卡片右侧相邻操作图标间距（如播放与加/勾之间）
  static const double soundCardActionGap = 12;

  /// 卡片音效名称字号
  static const double soundCardTitleSize = 16;

  /// 卡片圆角
  static const double soundCardRadius = 20;

  // --- 音效库空状态 ---
  /// 「还没有录制音效」空状态图标的宽高
  static const double soundEmptyStateIcon = 56;

  // --- 相册 AppBar ---
  /// 相册列表 / 大图预览等 AppBar 右侧 PNG 操作图标尺寸
  static const double galleryAppBarActionIcon = 20;

  // --- 录制对话框（对齐 static/recording-dialog.html）---
  static const double dialogWidth = 300;
  static const double dialogRadius = 20;
  static const double dialogPaddingH = 16;
  static const double dialogPaddingTop = 20;
  static const double dialogPaddingBottom = 16;
  static const double dialogTitleSize = 17;
  static const double dialogInputHeight = 50;
  static const double dialogBtnHeight = 46;
  static const double dialogFontSize = 15;
  static const double dialogHintFontSize = 13;
}
