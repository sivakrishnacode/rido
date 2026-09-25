import 'package:flutter/material.dart';
import 'package:rido_ui/rido_ui.dart';

/// A 1px dashed rounded border (the "+ Add" saved-place tile on P-07).
class DashedBorder extends StatelessWidget {
  const DashedBorder({super.key, required this.child, this.color = RidoColors.navy300});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(foregroundPainter: _DashedPainter(color), child: child);
}

class _DashedPainter extends CustomPainter {
  _DashedPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(RidoRadii.card)).deflate(0.5);
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter old) => old.color != color;
}
