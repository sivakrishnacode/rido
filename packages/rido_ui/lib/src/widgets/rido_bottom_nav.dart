import 'package:flutter/material.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

/// One destination in [RidoBottomNav].
class RidoNavItem {
  const RidoNavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Bottom navigation (4 items): active item gets a coral-50 pill behind a filled coral icon.
class RidoBottomNav extends StatelessWidget {
  const RidoBottomNav({super.key, required this.items, required this.currentIndex, required this.onTap});

  final List<RidoNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: RidoColors.surface,
        border: Border(top: BorderSide(color: RidoColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == currentIndex,
                    button: true,
                    label: items[i].label,
                    excludeSemantics: true,
                    child: InkWell(
                      key: ValueKey('nav-${items[i].label}'),
                      onTap: () => onTap(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 56,
                            height: 32,
                            decoration: BoxDecoration(
                              color: i == currentIndex ? RidoColors.coral50 : Colors.transparent,
                              borderRadius: RidoRadii.pillRadius,
                            ),
                            child: Icon(
                              items[i].icon,
                              fill: i == currentIndex ? 1 : 0,
                              color: i == currentIndex ? RidoColors.coral600 : RidoColors.navy500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            items[i].label,
                            style: t.caption.copyWith(
                              fontSize: 13,
                              color: i == currentIndex ? RidoColors.coral600 : RidoColors.navy500,
                              fontWeight: i == currentIndex ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
