import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// 深色圆角 Toast 提示（自动消失，无需点击）
class ToastMessage {
  ToastMessage._();

  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    showGeneralDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      barrierLabel: message,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, animation, secondaryAnimation) {
        Future.delayed(duration, () {
          if (ctx.mounted) Navigator.of(ctx).pop();
        });
        return Center(
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.toastBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textOnDark,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
