import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// 拍照倒计时覆盖层
class CountdownOverlay extends StatelessWidget {
  final int seconds;

  const CountdownOverlay({super.key, required this.seconds});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ColoredBox(
        color: Colors.black38,
        child: Center(
          child: Text(
            '$seconds',
            style: const TextStyle(
              fontSize: 96,
              fontWeight: FontWeight.bold,
              color: AppColors.textOnDark,
            ),
          ),
        ),
      ),
    );
  }
}
