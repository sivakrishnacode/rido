import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

/// Navy-900 block at the top of driver screens. It extends under the status bar
/// (light status icons) and pads its [child] below it.
class NavyHeader extends StatelessWidget {
  const NavyHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(TtSpacing.gutter, TtSpacing.m, TtSpacing.gutter, TtSpacing.l),
    this.color = TtColors.navy900,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
        child: Material(
          color: color,
          child: SafeArea(bottom: false, child: Padding(padding: padding, child: child)),
        ),
      );
}

/// White panel pinned to the bottom of a map screen: rounded top, soft shadow,
/// optional drag handle. Wraps its content in a bottom [SafeArea].
class BottomPanel extends StatelessWidget {
  const BottomPanel({super.key, required this.child, this.handle = false, this.padding});

  final Widget child;
  final bool handle;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: TtColors.surface,
          borderRadius: TtRadii.sheetTop,
          boxShadow: TtShadows.raised,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: padding ?? EdgeInsets.fromLTRB(TtSpacing.gutter, handle ? 0 : 20, TtSpacing.gutter, TtSpacing.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [if (handle) const SheetHandle(), child],
            ),
          ),
        ),
      );
}
