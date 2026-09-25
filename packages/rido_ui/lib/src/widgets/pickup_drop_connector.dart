import 'package:flutter/material.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

import 'location_markers.dart';

/// Connected pickup → drop pair with a dotted line between the dot and the pin.
class PickupDropConnector extends StatelessWidget {
  const PickupDropConnector({
    super.key,
    required this.pickupTitle,
    required this.dropTitle,
    this.pickupSubtitle,
    this.dropSubtitle,
    this.pickupLabel,
    this.dropLabel,
    this.pickupSubtitleColor,
    this.onPickupTap,
    this.onDropTap,
    this.dense = false,
  });

  final String pickupTitle;
  final String? pickupSubtitle;
  final String dropTitle;
  final String? dropSubtitle;

  /// Small caption above the title ("Pickup", "Drop").
  final String? pickupLabel;
  final String? dropLabel;
  final Color? pickupSubtitleColor;
  final VoidCallback? onPickupTap;
  final VoidCallback? onDropTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    Widget text(String? label, String title, String? sub, Color? subColor, VoidCallback? onTap) => InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: dense ? 2 : 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null) Text(label, style: t.caption),
                Text(title, style: t.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (sub != null)
                  Text(sub,
                      style: t.bodySmall.copyWith(color: subColor ?? RidoColors.navy500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                SizedBox(height: pickupLabel != null ? 20 : 6),
                const PickupDot(size: 10),
                const Expanded(child: _DottedLine()),
                const DropPin(size: 20),
                SizedBox(height: dropSubtitle != null ? 22 : 6),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text(pickupLabel, pickupTitle, pickupSubtitle, pickupSubtitleColor, onPickupTap),
                SizedBox(height: dense ? 8 : 14),
                text(dropLabel, dropTitle, dropSubtitle, null, onDropTap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DottedLine extends StatelessWidget {
  const _DottedLine();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DotsPainter(), child: const SizedBox(width: 2));
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = RidoColors.navy500
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (double y = 4; y < size.height - 2; y += 6) {
      canvas.drawLine(Offset(size.width / 2, y), Offset(size.width / 2, y + 2), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
