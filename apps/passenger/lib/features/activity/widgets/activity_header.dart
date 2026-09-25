import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../../common/passenger_shell.dart';
import '../../../router/routes.dart';

/// The Activity tabs.
const activityTabs = ['All', 'Rides', 'Parcels'];

/// White "Activity" header with the All · Rides · Parcels tab bar (P-21, S-06, S-07b).
/// Uses [controller], or the surrounding DefaultTabController.
class ActivityHeader extends StatelessWidget {
  const ActivityHeader({super.key, this.controller});
  final TabController? controller;

  @override
  Widget build(BuildContext context) => Material(
        color: RidoColors.surface,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Semantics(header: true, child: Text('Activity', style: context.type.display)),
              ),
              TabBar(
                controller: controller,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorWeight: 3,
                labelStyle: context.type.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                unselectedLabelStyle: context.type.bodyMedium,
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                tabs: [for (final t in activityTabs) Tab(height: 52, text: t)],
              ),
            ],
          ),
        ),
      );
}

/// Bottom nav for Activity state frames opened on their own (S-06, S-07b showcases):
/// the real tab shell provides it in the flow.
class ActivityShowcaseNav extends StatelessWidget {
  const ActivityShowcaseNav({super.key});

  static const _roots = [Routes.ride, Routes.parcel, Routes.activity, Routes.account];

  @override
  Widget build(BuildContext context) => RidoBottomNav(
        items: PassengerShell.items,
        currentIndex: 2,
        onTap: (i) => context.go(_roots[i]),
      );
}
