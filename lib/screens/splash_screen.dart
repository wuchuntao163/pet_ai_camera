import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_branding.dart';
import '../constants/app_colors.dart';
import '../data/app_cache_store.dart';
import '../router/app_routes.dart';
import '../services/app_launch.dart';

/// 开屏：居中 Logo（固定尺寸）+ 应用名称，初始化完成后进入相机
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    AppLaunch.instance.addListener(_onLaunchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AppLaunch.instance.ready) _goCamera();
    });
  }

  @override
  void dispose() {
    AppLaunch.instance.removeListener(_onLaunchChanged);
    super.dispose();
  }

  void _onLaunchChanged() {
    if (AppLaunch.instance.ready && mounted) _goCamera();
  }

  void _goCamera() {
    context.go(AppRoutes.camera);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.settingsBg,
      body: Center(
        child: ListenableBuilder(
          listenable: AppCacheStore.instance,
          builder: (context, _) {
            final cache = AppCacheStore.instance;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SplashLogo(logoUrl: cache.appLogoUrl),
                const SizedBox(height: 20),
                Text(
                  cache.displayAppName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo({this.logoUrl});

  final String? logoUrl;

  static const _size = 96.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    final url = logoUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: _size,
        height: _size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _localLogo(),
      );
    }
    return _localLogo();
  }

  Widget _localLogo() {
    return Image.asset(
      AppBranding.logoAsset,
      width: _size,
      height: _size,
      fit: BoxFit.contain,
    );
  }
}
