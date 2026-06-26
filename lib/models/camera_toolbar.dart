/// 顶部工具栏槽位（从左到右：设置 | 比例 | 连拍 | 定时 | 闪光灯）
enum CameraToolbarSlot {
  aspectRatio,
  burst,
  timer,
  flash,
}

/// 顶部弹窗类型
enum CameraPopupType {
  none,
  aspectRatio,
  burst,
  timer,
}

CameraPopupType? popupForSlot(CameraToolbarSlot slot) {
  return switch (slot) {
    CameraToolbarSlot.aspectRatio => CameraPopupType.aspectRatio,
    CameraToolbarSlot.burst => CameraPopupType.burst,
    CameraToolbarSlot.timer => CameraPopupType.timer,
    CameraToolbarSlot.flash => null,
  };
}
