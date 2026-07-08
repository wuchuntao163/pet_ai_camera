/// 路由路径常量
abstract final class AppRoutes {
  static const splash = '/splash';
  static const camera = '/';
  static const gallery = '/gallery';

  static const aiPetCopy = '/gallery/ai-copy';
  static const photoPalette = '/gallery/palette';

  static String galleryPhoto(int index) => '/gallery/photo/$index';
}
