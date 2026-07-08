import 'dart:math';

import 'package:flutter/material.dart';

/// 随机种子生成的柔和不规则圆，用于趣味文案装饰
class OrganicBubble extends StatelessWidget {
  final Color color;
  final int seed;
  final double size;

  const OrganicBubble({
    super.key,
    required this.color,
    required this.seed,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OrganicBubblePainter(color: color, seed: seed),
      ),
    );
  }
}

class _OrganicBubblePainter extends CustomPainter {
  final Color color;
  final int seed;

  _OrganicBubblePainter({required this.color, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = min(size.width, size.height) / 2 * 0.92;
    final random = Random(seed);

    // 低频正弦叠加，形成不规则但协调的轮廓
    final amp1 = 0.05 + random.nextDouble() * 0.05;
    final amp2 = 0.03 + random.nextDouble() * 0.04;
    final phase1 = random.nextDouble() * 2 * pi;
    final phase2 = random.nextDouble() * 2 * pi;
    const segments = 64;

    final path = Path();
    for (var i = 0; i <= segments; i++) {
      final angle = (i / segments) * 2 * pi;
      final wobble =
          1 + amp1 * sin(2 * angle + phase1) + amp2 * sin(3 * angle + phase2);
      final radius = baseRadius * wobble;
      final point = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _OrganicBubblePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.seed != seed;
  }
}
