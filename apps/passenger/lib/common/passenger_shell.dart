import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_ui/rido_ui.dart';

/// Home shell: four tabs (Ride · Parcel · Activity · Account), each with its own stack.
class PassengerShell extends StatelessWidget {
  const PassengerShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const items = [
    RidoNavItem(icon: Symbols.directions_car_rounded, label: 'Ride'),
    RidoNavItem(icon: Symbols.deployed_code_rounded, label: 'Parcel'),
    RidoNavItem(icon: Symbols.receipt_long_rounded, label: 'Activity'),
    RidoNavItem(icon: Symbols.person_rounded, label: 'Account'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: RidoBottomNav(
        items: items,
        currentIndex: navigationShell.currentIndex,
        // Tapping the active tab pops it back to its root.
        onTap: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
      ),
    );
  }
}
