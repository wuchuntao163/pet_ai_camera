/// 路由路径常量
abstract final class AppRoutes {
  static const splash = '/splash';
  static const camera = '/';
  static const gallery = '/gallery';

  static String galleryPhoto(int index) => '/gallery/photo/$index';
}
