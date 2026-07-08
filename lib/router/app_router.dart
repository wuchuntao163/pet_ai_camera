import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_services.dart';
import '../screens/ai_pet_copy_screen.dart';
import '../screens/camera_screen.dart';
import '../models/app_photo.dart';
import '../screens/photo_gallery_screen.dart';
import '../screens/photo_palette_screen.dart';
import '../screens/photo_viewer_screen.dart';
import '../screens/splash_screen.dart';
import 'app_routes.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SplashScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.camera,
        pageBuilder: (context, state) => const NoTransitionPage(
          child: CameraScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.gallery,
        pageBuilder: (context, state) => _fadePage(
          state,
          PhotoGalleryScreen(
            galleryService: AppServices.instance.photoGallery,
          ),
        ),
        routes: [
          GoRoute(
            path: 'ai-copy',
            pageBuilder: (context, state) {
              final photo = state.extra as AppPhoto?;
              if (photo == null) {
                return _fadePage(
                  state,
                  const Scaffold(
                    body: Center(child: Text('照片不存在')),
                  ),
                );
              }
              return _fadePage(
                state,
                AiPetCopyScreen(
                  photo: photo,
                  galleryService: AppServices.instance.photoGallery,
                ),
              );
            },
          ),
          GoRoute(
            path: 'palette',
            pageBuilder: (context, state) {
              final photo = state.extra as AppPhoto?;
              if (photo == null) {
                return _fadePage(
                  state,
                  const Scaffold(
                    body: Center(child: Text('照片不存在')),
                  ),
                );
              }
              return _fadePage(
                state,
                PhotoPaletteScreen(
                  photo: photo,
                  galleryService: AppServices.instance.photoGallery,
                ),
              );
            },
          ),
          GoRoute(
            path: 'photo/:index',
            pageBuilder: (context, state) {
              final index =
                  int.tryParse(state.pathParameters['index'] ?? '') ?? 0;
              return _fadePage(
                state,
                PhotoViewerScreen(
                  galleryService: AppServices.instance.photoGallery,
                  initialIndex: index,
                ),
              );
            },
          ),
        ],
      ),
    ],
  );
}

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 150),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        ),
        child: child,
      );
    },
  );
}
