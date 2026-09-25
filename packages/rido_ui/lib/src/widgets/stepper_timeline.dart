import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

/// Status stepper: "Driver assigned ● → At pickup ○ → Picked up ○ → Delivered ○".
/// Steps before [currentIndex] are done (green check), the current one is coral.
class StepperTimeline extends StatelessWidget {
  const StepperTimeline({
    super.key,
    required this.steps,
    required this.currentIndex,
    this.axis = Axis.horizontal,
    this.subtitles,
  });

  final List<String> steps;
  final int currentIndex;
  final Axis axis;

  /// Optional captions under each step (vertical only), e.g. times.
  final List<String?>? subtitles;

  @override
  Widget build(BuildContext context) =>
      axis == Axis.horizontal ? _horizontal(context) : _vertical(context);

  Widget _dot(int i) {
    final done = i < currentIndex;
    final current = i == currentIndex;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? RidoColors.success : (current ? RidoColors.coral600 : RidoColors.surface),
        border: Border.all(color: done ? RidoColors.success : (current ? RidoColors.coral600 : RidoColors.navy300), width: 2),
        boxShadow: current ? const [BoxShadow(color: RidoColors.coral100, blurRadius: 0, spreadRadius: 4)] : null,
      ),
      child: done
          ? const Icon(Symbols.check_rounded, size: 16, color: Colors.white, weight: 700)
          : current
              ? Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)))
              : null,
    );
  }

  Widget _horizontal(BuildContext context) {
    final t = context.type;
    return Semantics(
      label: 'Step ${currentIndex + 1} of ${steps.length}: ${steps[currentIndex.clamp(0, steps.length - 1)]}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: i == 0
                            ? const SizedBox()
                            : Container(height: 2, color: i <= currentIndex ? RidoColors.success : RidoColors.divider),
                      ),
                      _dot(i),
                      Expanded(
                        child: i == steps.length - 1
                            ? const SizedBox()
                            : Container(height: 2, color: i < currentIndex ? RidoColors.success : RidoColors.divider),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[i],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: t.caption.copyWith(
                      color: i == currentIndex ? RidoColors.navy900 : RidoColors.navy500,
                      fontWeight: i == currentIndex ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _vertical(BuildContext context) {
    final t = context.type;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    _dot(i),
                    if (i < steps.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          constraints: const BoxConstraints(minHeight: 20),
                          color: i < currentIndex ? RidoColors.success : RidoColors.divider,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16, top: 1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i],
                          style: (i == currentIndex ? t.bodySemibold : t.body)
                              .copyWith(color: i > currentIndex ? RidoColors.navy500 : RidoColors.navy900),
                        ),
                        if (subtitles != null && i < subtitles!.length && subtitles![i] != null)
                          Text(subtitles![i]!, style: t.caption),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
