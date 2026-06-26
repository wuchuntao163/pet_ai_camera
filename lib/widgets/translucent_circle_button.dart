import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// 圆形半透明按钮组件
class TranslucentCircleButton extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final double borderRadius;
  final VoidCallback? onTap;
  final Widget child;

  const TranslucentCircleButton({
    super.key,
    this.size = 48,
    this.backgroundColor,
    this.borderRadius = 48,
    this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.translucentBtn,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Center(child: child),
      ),
    );
  }
}
