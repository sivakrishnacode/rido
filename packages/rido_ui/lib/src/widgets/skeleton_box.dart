import 'package:flutter/material.dart';

import '../theme/rido_colors.dart';

/// Grey shimmer placeholder block. The shimmer is a sliding gradient driven by an
/// AnimationController (no package). Wrap many boxes in one [SkeletonShimmer] to share a
/// single controller; a lone box animates itself.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 8, this.circle = false});

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final scope = _ShimmerScope.maybeOf(context);
    final box = _box(scope?.value ?? 0);
    if (scope != null) return box;
    return SkeletonShimmer(child: Builder(builder: (c) => _box(_ShimmerScope.maybeOf(c)!.value)));
  }

  Widget _box(double t) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment(-1.5 + t * 3, 0),
            end: Alignment(-0.5 + t * 3, 0),
            colors: const [RidoColors.inputBg, RidoColors.divider, RidoColors.inputBg],
          ),
        ),
      );
}

/// Provides one shimmer animation to every [SkeletonBox] below it.
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({super.key, required this.child});
  final Widget child;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading',
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => _ShimmerScope(value: _c.value, child: child!),
          child: widget.child,
        ),
      );
}

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({required this.value, required super.child});
  final double value;

  static _ShimmerScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_ShimmerScope>();

  @override
  bool updateShouldNotify(_ShimmerScope old) => old.value != value;
}
