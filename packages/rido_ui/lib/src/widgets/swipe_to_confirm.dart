import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

/// Swipe-to-confirm button (driver app: "Swipe to start ride"). Releasing past 85%
/// confirms; otherwise the knob springs back. Screen readers get a plain tap action.
class SwipeToConfirm extends StatefulWidget {
  const SwipeToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.color = RidoColors.navy900,
    this.knobColor = RidoColors.coral600,
    this.height = 60,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onConfirmed;
  final Color color;
  final Color knobColor;
  final double height;
  final bool enabled;

  @override
  State<SwipeToConfirm> createState() => _SwipeToConfirmState();
}

class _SwipeToConfirmState extends State<SwipeToConfirm> with SingleTickerProviderStateMixin {
  double _dx = 0;
  double _max = 1;
  late final AnimationController _spring =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 220))..addListener(_onSpring);
  double _springFrom = 0;
  double _springTo = 0;
  Timer? _reset;

  void _onSpring() {
    setState(() => _dx = _springFrom + (_springTo - _springFrom) * Curves.easeOut.transform(_spring.value));
  }

  void _animateTo(double target) {
    _springFrom = _dx;
    _springTo = target;
    _spring.forward(from: 0);
  }

  void _confirm() {
    widget.onConfirmed();
    // Reset for reuse if the screen stays.
    _reset?.cancel();
    _reset = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _animateTo(0);
    });
  }

  @override
  void dispose() {
    _reset?.cancel();
    _spring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final knob = widget.height - 8;
    return Semantics(
      button: true,
      label: widget.label,
      enabled: widget.enabled,
      onTap: widget.enabled ? _confirm : null,
      excludeSemantics: true,
      child: LayoutBuilder(builder: (context, c) {
        _max = (c.maxWidth - knob - 8).clamp(1, double.infinity);
        final progress = (_dx / _max).clamp(0.0, 1.0);
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.enabled ? widget.color : RidoColors.divider,
            borderRadius: RidoRadii.pillRadius,
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned.fill(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(left: knob),
                    child: Opacity(
                      opacity: 1 - progress * 0.8,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.button
                            .copyWith(color: widget.enabled ? Colors.white : RidoColors.navy500),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 4 + _dx,
                child: GestureDetector(
                  key: const ValueKey('swipe-knob'),
                  onHorizontalDragUpdate: widget.enabled
                      ? (d) => setState(() => _dx = (_dx + d.delta.dx).clamp(0, _max))
                      : null,
                  onHorizontalDragEnd: widget.enabled
                      ? (_) {
                          if (_dx / _max >= 0.85) {
                            _animateTo(_max);
                            _confirm();
                          } else {
                            _animateTo(0);
                          }
                        }
                      : null,
                  child: Container(
                    width: knob,
                    height: knob,
                    decoration: BoxDecoration(
                      color: widget.enabled ? widget.knobColor : RidoColors.navy300,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Symbols.keyboard_double_arrow_right_rounded, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
