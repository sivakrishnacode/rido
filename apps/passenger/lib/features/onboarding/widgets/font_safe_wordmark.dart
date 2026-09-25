import 'package:flutter/material.dart';
import 'package:rido_ui/rido_ui.dart';

/// [RidoWordmark] measures its letters during build, so it is rebuilt here whenever
/// fonts finish loading (otherwise the first frame's fallback metrics stick and the
/// wordmark sits off-centre with a misplaced dot).
class FontSafeWordmark extends StatefulWidget {
  const FontSafeWordmark({
    super.key,
    this.size = 48,
    this.color = RidoColors.navy900,
    this.dotColor = RidoColors.coral500,
  });

  final double size;
  final Color color;
  final Color dotColor;

  @override
  State<FontSafeWordmark> createState() => _FontSafeWordmarkState();
}

class _FontSafeWordmarkState extends State<FontSafeWordmark> {
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_onFonts);
  }

  void _onFonts() {
    if (mounted) setState(() => _generation++);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onFonts);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RidoWordmark(key: ValueKey(_generation), size: widget.size, color: widget.color, dotColor: widget.dotColor);
}
