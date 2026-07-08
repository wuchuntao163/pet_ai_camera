/// 应用颜色常量定义
///
/// 所有颜色值均来自设计稿，确保视觉还原精度。
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // --- 主色调 ---
  /// 主题橙色，用于滑块、开关、按钮等高亮元素
  static const Color primary = Color(0xFFF97316);

  /// 主题红色（录制按钮）
  static const Color recordRed = Color(0xFFE91E63);

  /// 删除确认等危险操作文字色（正红）
  static const Color deleteRed = Color(0xFFFF0000);

  /// 大图页「调色盘 / 它想说」按钮背景
  static const Color paletteActionBg = Color(0xFFA3948C);

  /// 它想说底部按钮渐变
  static const Color aiCopyRegenerateGradientStart = Color(0xFFAAD6FA);
  static const Color aiCopyRegenerateGradientEnd = Color(0xFF86B4ED);
  static const Color aiCopySaveGradientStart = Color(0xFFC7E8BC);
  static const Color aiCopySaveGradientEnd = Color(0xFFBAE8C7);
  static const Color aiCopyShareGradientStart = Color(0xFFF7B7C0);
  static const Color aiCopyShareGradientEnd = Color(0xFFD6B3E9);

  // --- 背景色 ---
  /// 相机界面纯黑背景
  static const Color cameraBg = Color(0xFF000000);

  /// 半透明遮罩（设置面板背景）
  static const Color overlayDark = Color(0x80000000);

  /// 半透明遮罩（对话框背景）
  static const Color overlayDialog = Color(0xA6000000);

  /// 设置面板白色背景
  static const Color settingsBg = Color(0xFFFFFFFF);

  /// 音效库白色背景
  static const Color soundLibraryBg = Color(0xFFFFFFFF);

  /// 列表项卡片背景
  static const Color cardBg = Color(0xFFFFFFFF);

  // --- 工具栏按钮背景 ---
  /// 顶部工具栏/侧边栏半透明按钮背景
  static const Color translucentBtn = Color(0x592D2D2D);

  /// 分段选择器选中项背景
  static const Color bottomTranslucentBtn = Color(0x4D2D2D2D);

  // --- 文字颜色 ---
  /// 主要文字颜色（标题）
  static const Color textPrimary = Color(0xFF111827);

  /// 次要文字颜色（副标题）
  static const Color textSecondary = Color(0xFF374151);

  /// 辅助文字 / 占位符
  static const Color textHint = Color(0xFF9CA3AF);

  /// 浅色辅助文字
  static const Color textLight = Color(0xFFD1D5DB);

  /// 白色文字（深色背景上）
  static const Color textOnDark = Color(0xFFFFFFFF);

  /// 灰色文字（设置面板百分比）
  static const Color textGray = Color(0xFF6B7280);

  // --- 边框与分割线 ---
  /// 卡片边框颜色
  static const Color borderCard = Color(0xFFF3F4F6);

  /// 分割线 / 滑块轨道
  static const Color divider = Color(0xFFE5E7EB);

  /// 选中态边框
  static const Color borderSelected = Color(0xFFFBD38D);

  // --- 特殊状态 ---
  /// 开关关闭态背景
  static const Color switchOff = Color(0xFFD1D5DB);

  /// 开关开启态背景（使用 primary）

  /// 选中态选项卡背景
  static const Color tabSelectedBg = Color(0xFFFEF3C7);

  /// 免费标签绿色
  static const Color freeTagGreen = Color(0xFF22C55E);

  /// 宠物图标背景色
  static const Color petIconBg = Color(0xFFFFEDD5);

  /// 底部栏 / 预览留白背景（半透明黑色，与设计稿 camera-bottom 一致）
  static const Color bottomBarBg = Color(0xD9000000);

  // --- 音效库专用 ---
  /// 我的录制标签激活背景（与分类 Tab 选中色一致）
  static const Color tabMyRecordingBg = primary;

  /// 萌宠分类标签激活背景
  static const Color tabCatActiveBg = primary;

  /// 音效库标签文字（激活态）
  static const Color tabTextActive = Color(0xFFFFFFFF);

  /// 音效库标签文字（非激活态）
  static const Color tabTextInactive = Color(0xFF6B7280);

  /// 音效库标题文字
  static const Color soundTitle = Color(0xFF1E293B);

  /// 音效卡片文字
  static const Color soundCardTitle = Color(0xFF334155);

  /// 音效卡片播放按钮（与主题选中色一致）
  static const Color notePurple = primary;

  /// 「录制新音效」按钮背景
  static const Color myRecordingBg = primary;

  /// 音效库标签非激活边框
  static const Color tabInactiveBorder = Color(0xFFE5E7EB);

  // --- 暗色工具栏按钮 ---
  /// 顶部工具栏按钮背景（音效库模式）
  static const Color darkToolbarBtn = Color(0xFF27272A);

  // --- 录制对话框 ---
  /// 对话框背景
  static const Color dialogBg = Color(0xFFFFFFFF);

  /// 输入框边框
  static const Color inputBorder = Color(0xFFE5E7EB);

  /// 开始录制按钮（禁用态）
  static const Color recordBtnDisabled = Color(0xFFE5E7EB);

  /// 取消按钮边框
  static const Color cancelBtnBorder = Color(0xFFE5E7EB);

  /// 取消按钮文字
  static const Color cancelBtnText = Color(0xFF374151);

  /// 对话框标题文字
  static const Color dialogTitle = Color(0xFF111827);

  /// Toast 提示背景
  static const Color toastBg = Color(0xE6333333);
}