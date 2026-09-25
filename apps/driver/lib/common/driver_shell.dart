import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_ui/rido_ui.dart';

/// Home shell: four tabs (Home · Earnings · Plan · Account), each with its own stack.
class DriverShell extends StatelessWidget {
  const DriverShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const items = [
    RidoNavItem(icon: Symbols.home_rounded, label: 'Home'),
    RidoNavItem(icon: Symbols.payments_rounded, label: 'Earnings'),
    RidoNavItem(icon: Symbols.workspace_premium_rounded, label: 'Plan'),
    RidoNavItem(icon: Symbols.person_rounded, label: 'Account'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: navigationShell,
        bottomNavigationBar: RidoBottomNav(
          items: items,
          currentIndex: navigationShell.currentIndex,
          onTap: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
        ),
      );
}
