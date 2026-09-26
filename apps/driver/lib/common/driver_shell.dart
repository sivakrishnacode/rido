import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

/// Home shell: four tabs (Home · Earnings · Plan · Account), each with its own stack. In the free app
/// (paid plans off) the Plan tab is hidden and the bar shows Home · Earnings · Account.
class DriverShell extends ConsumerWidget {
  const DriverShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const items = [
    RidoNavItem(icon: Symbols.home_rounded, label: 'Home'),
    RidoNavItem(icon: Symbols.payments_rounded, label: 'Earnings'),
    RidoNavItem(icon: Symbols.workspace_premium_rounded, label: 'Plan'),
    RidoNavItem(icon: Symbols.person_rounded, label: 'Account'),
  ];

  /// Branch index of the Plan tab.
  static const planBranch = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Visible tab → shell branch.
    final branches = [
      for (var i = 0; i < items.length; i++)
        if (i != planBranch || ref.watch(driverPlansEnabledProvider)) i,
    ];
    final current = branches.indexOf(navigationShell.currentIndex);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: RidoBottomNav(
        items: [for (final b in branches) items[b]],
        currentIndex: current < 0 ? 0 : current,
        onTap: (i) => navigationShell.goBranch(branches[i], initialLocation: branches[i] == navigationShell.currentIndex),
      ),
    );
  }
}
