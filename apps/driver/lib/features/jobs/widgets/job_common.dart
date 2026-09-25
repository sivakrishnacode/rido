import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../../router/routes.dart';

/// Pops the current screen, or goes Home when it was opened directly (deep link / test).
void popOrHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.home);
  }
}

/// Back during an active job: "Leave this screen? Your trip continues." → Home, where the
/// D-14b banner reopens the job.
Future<void> confirmLeaveJob(BuildContext context, {bool delivery = false}) async {
  final leave = await showRidoConfirm(
    context,
    title: 'Leave this screen?',
    message: delivery ? 'Your delivery continues. Reopen it from Home.' : 'Your trip continues. Reopen it from Home.',
    confirmLabel: 'Go to Home',
    cancelLabel: 'Stay here',
    icon: Symbols.directions_rounded,
  );
  if (leave && context.mounted) context.go(Routes.home);
}

/// "Priya" → "P", "Meena Ravi" → "MR".
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

/// 56px round icon button (call / chat) with a tooltip.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.background = RidoColors.coral50,
    this.foreground = RidoColors.coral600,
    this.size = 56,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: background,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(dimension: size, child: Icon(icon, color: foreground, fill: 1)),
          ),
        ),
      );
}

/// Dark pill button used over maps and in navy headers ("Navigate").
class NavigatePill extends StatelessWidget {
  const NavigatePill({super.key, required this.onPressed, this.onDark = false});

  final VoidCallback onPressed;

  /// Navy-700 fill for use inside a navy header.
  final bool onDark;

  @override
  Widget build(BuildContext context) => Material(
        color: onDark ? RidoColors.navy700 : RidoColors.navy900,
        shape: const StadiumBorder(),
        elevation: onDark ? 0 : 4,
        shadowColor: RidoColors.shadow,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Symbols.near_me_rounded, color: Colors.white, fill: 1, size: 22),
                const SizedBox(width: RidoSpacing.s),
                Text('Navigate', style: context.type.bodySemibold.copyWith(color: Colors.white)),
              ]),
            ),
          ),
        ),
      );
}
