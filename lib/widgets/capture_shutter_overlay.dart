import 'package:flutter/material.dart';

/// 快门闪白：瞬间出现、快速消失
class CaptureShutterOverlay extends StatelessWidget {
  final double flashOpacity;

  const CaptureShutterOverlay({
    super.key,
    required this.flashOpacity,
  });

  @override
  Widget build(BuildContext context) {
    if (flashOpacity <= 0) return const SizedBox.shrink();

    return IgnorePointer(
      child: Opacity(
        opacity: flashOpacity,
        child: const ColoredBox(color: Colors.white),
      ),
    );
  }
}
