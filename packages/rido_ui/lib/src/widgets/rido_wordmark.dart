import 'package:flutter/material.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

/// The lowercase "rido" wordmark in bold rounded type with a coral dot on the "i".
/// Drawn as text with a dotless "ı" plus a measured coral circle, so it scales cleanly.
class RidoWordmark extends StatefulWidget {
  const RidoWordmark({super.key, this.size = 48, this.color = RidoColors.navy900, this.dotColor = RidoColors.coral500});

  /// Font size of the letters.
  final double size;
  final Color color;
  final Color dotColor;

  @override
  State<RidoWordmark> createState() => _RidoWordmarkState();
}

class _RidoWordmarkState extends State<RidoWordmark> {
  // The dot position is measured from the font, so re-measure when fonts finish loading.
  void _fontsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final color = widget.color;
    final dotColor = widget.dotColor;
    final style = context.type.display.copyWith(
      fontSize: size,
      height: 1.1,
      color: color,
      fontWeight: FontWeight.w700,
      letterSpacing: -size * 0.02,
    );
    final dir = Directionality.of(context);
    final r = TextPainter(text: TextSpan(text: 'r', style: style), textDirection: dir)..layout();
    final ri = TextPainter(text: TextSpan(text: 'rı', style: style), textDirection: dir)..layout();
    final full = TextPainter(text: TextSpan(text: 'rıdo', style: style), textDirection: dir)..layout();
    final iWidth = ri.width - r.width;
    final dot = size * 0.2;
    return Semantics(
      label: 'rido',
      excludeSemantics: true,
      child: SizedBox(
        width: full.width,
        height: full.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Text('rıdo', style: style),
            Positioned(
              left: r.width + iWidth / 2 - dot / 2,
              top: full.height * 0.1,
              child: Container(width: dot, height: dot, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            ),
          ],
        ),
      ),
    );
  }
}
