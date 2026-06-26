import '../services/camera_settings_store.dart';
import '../services/photo_gallery_service.dart';

/// 应用级单例服务，供路由与各页面共享
class AppServices {
  AppServices._();

  static final AppServices instance = AppServices._();

  final PhotoGalleryService photoGallery = PhotoGalleryService();
  final CameraSettingsStore cameraSettings = CameraSettingsStore();
}
