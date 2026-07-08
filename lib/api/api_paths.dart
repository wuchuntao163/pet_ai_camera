/// 全部接口路径 + 功能说明（详见项目根目录 [api.md]）
///
/// 用法：`Api.get(ApiPaths.getConfig)` / `Api.post(ApiPaths.loginByUuid, data: {...})`
class ApiPaths {
  ApiPaths._();

  // ═══════════════════════════════════════════════════════════
  //  无需登录 · Common 公共模块
  // ═══════════════════════════════════════════════════════════

  /// 获取应用配置 · GET
  static const getConfig = '/api/common/getConfig';

  /// 获取应用信息（名称/logo/版本） · GET
  static const getAppInfo = '/api/common/getAppInfo';

  /// 获取导航列表（type:1 中间导航，2 底部导航） · GET
  static const nav = '/api/common/nav';

  /// 获取语言列表 · GET
  static const getLanguage = '/api/common/getLanguage';

  /// 获取导航信息 · GET
  static const navigation = '/api/common/navigation';

  /// 获取会员套餐列表 · GET
  static const setMeal = '/api/common/setMeal';

  /// 获取 Access Token · GET
  static const getNew = '/api/common/getNew';

  /// 获取 Banner 轮播图 · GET
  static const getBanner = '/api/common/getBanner';

  // ═══════════════════════════════════════════════════════════
  //  无需登录 · Login 登录模块
  // ═══════════════════════════════════════════════════════════

  /// UUID 登录/注册 · POST
  static const loginByUuid = '/api/login/loginByUuid';

  /// 微信 OpenId 登录 · POST
  static const loginByOpenId = '/api/login/loginByOpenId';

  /// 获取短信验证码 · POST
  static const getSmsCode = '/api/login/getSmsCode';

  // ═══════════════════════════════════════════════════════════
  //  需要登录 · Base 文件上传
  // ═══════════════════════════════════════════════════════════

  /// 通用文件上传 · POST
  static const upload = '/api/base/upload';

  /// 上传模拟图片 · POST
  static const uploadMimicImage = '/api/base/uploadMimicImage';

  /// 上传字体文件 · POST
  static const uploadTtf = '/api/base/uploadTtf';

  /// 删除文件 · POST
  static const delFile = '/api/base/delFile';

  // ═══════════════════════════════════════════════════════════
  //  需要登录 · Index 首页
  // ═══════════════════════════════════════════════════════════

  /// 获取弹窗广告 · GET
  static const pop = '/api/index/pop';

  /// 提交意见反馈 · POST
  static const opinion = '/api/index/opinion';

  // ═══════════════════════════════════════════════════════════
  //  需要登录 · User 用户
  // ═══════════════════════════════════════════════════════════

  /// 获取用户信息 · GET
  static const getUserInfo = '/api/user/getUserInfo';

  /// 更新用户信息 · POST
  static const updateUserInfo = '/api/user/updateUserInfo';

  /// 更新用户头像/昵称 · POST
  static const updateUserAvatar = '/api/user/updateUserAvatar';

  /// 更新免费使用次数 · POST
  static const updateUserFreeTimes = '/api/user/updateUserFreeTimes';

  /// 绑定手机号 · POST
  static const bindPhone = '/api/user/bindPhone';

  /// 注销账号 · POST
  static const cancelAccount = '/api/user/cancelAccount';

  // ═══════════════════════════════════════════════════════════
  //  需要登录 · Camera 相机
  // ═══════════════════════════════════════════════════════════

  /// 获取音效分类列表 · GET
  static const getSoundCategories = '/api/camera/getSoundCategories';

  /// 获取音效列表 · GET
  static const getSoundEffects = '/api/camera/getSoundEffects';

  /// 设置音效排序 · POST
  static const setSoundEffectSort = '/api/camera/setSoundEffectSort';

  /// 添加用户自定义音效 · POST
  static const addCustomSoundEffect = '/api/camera/addCustomSoundEffect';

  /// 删除用户自定义音效 · POST
  static const deleteCustomSoundEffect = '/api/camera/deleteCustomSoundEffect';

  /// 保存摄像头记录 · POST
  static const saveCameraRecord = '/api/camera/saveCameraRecord';

  /// 获取摄像头记录列表 · GET
  static const getCameraRecords = '/api/camera/getCameraRecords';

  /// 删除摄像头记录 · POST
  static const deleteCameraRecord = '/api/camera/deleteCameraRecord';

  /// 删除所有摄像头记录 · POST
  static const deleteAllCameraRecords = '/api/camera/deleteAllCameraRecords';

  /// AI 趣味文案 · POST
  static const generatePetText = '/api/camera/generatePetText';
}
