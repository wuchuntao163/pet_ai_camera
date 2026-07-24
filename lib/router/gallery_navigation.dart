import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

/// 从调色盘/它想说/大图等子页回到相册，并保留相机页在栈底。
void popToGallery(BuildContext context) {
  final router = GoRouter.of(context);
  if (router.state.matchedLocation == AppRoutes.gallery) return;

  while (router.canPop()) {
    router.pop();
    if (router.state.matchedLocation == AppRoutes.gallery) return;
  }

  context.go(AppRoutes.gallery);
}

/// 相册页返回：优先 pop 到相机，栈空时显式回到相机页。
void popGalleryToCamera(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(AppRoutes.camera);
}
