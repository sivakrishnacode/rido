import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/rido_colors.dart';

/// Star rating. Display mode when [onChanged] is null; input mode otherwise (48px targets).
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.value, this.onChanged, this.size = 20, this.count = 5});

  /// Large input variant (P-20).
  const RatingStars.input({super.key, required this.value, required this.onChanged, this.size = 44, this.count = 5});

  final double value;
  final ValueChanged<int>? onChanged;
  final double size;
  final int count;

  static const labels = ['Terrible', 'Bad', 'Okay', 'Good', 'Excellent'];

  @override
  Widget build(BuildContext context) {
    final input = onChanged != null;
    return Semantics(
      label: 'Rating ${value.toStringAsFixed(input ? 0 : 1)} of $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= count; i++)
            input
                ? IconButton(
                    key: ValueKey('star-$i'),
                    tooltip: '$i star${i == 1 ? '' : 's'}',
                    iconSize: size,
                    padding: const EdgeInsets.all(2),
                    onPressed: () => onChanged!(i),
                    icon: _star(i),
                  )
                : _star(i),
        ],
      ),
    );
  }

  Widget _star(int i) {
    final filled = value >= i - 0.25;
    final half = !filled && value > i - 1 + 0.25;
    return Icon(
      half ? Symbols.star_half_rounded : Symbols.star_rounded,
      fill: filled || half ? 1 : 0,
      color: filled || half ? RidoColors.warning : RidoColors.navy300,
      size: size,
    );
  }
}
