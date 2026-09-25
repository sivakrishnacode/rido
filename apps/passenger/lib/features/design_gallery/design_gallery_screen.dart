import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../state/parcel_flow.dart';
import '../../state/passenger_session.dart';
import '../../state/ride_flow.dart';
import 'gallery_widgets.dart';

/// Design gallery (section 7): every designed frame plus the Demo controls.
class DesignGalleryScreen extends StatelessWidget {
  const DesignGalleryScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: RidoColors.background,
        appBar: RidoAppBar(
          title: 'Design gallery',
          bottom: TabBar(
            labelColor: RidoColors.coral600,
            unselectedLabelColor: RidoColors.navy500,
            indicatorColor: RidoColors.coral600,
            labelStyle: context.type.bodySmallMedium.copyWith(fontWeight: FontWeight.w600),
            unselectedLabelStyle: context.type.bodySmallMedium,
            tabs: const [Tab(text: 'Screens'), Tab(text: 'Demo controls')],
          ),
        ),
        body: const TabBarView(children: [GalleryScreensTab(), _DemoControlsTab()]),
      ),
    );
  }
}

class _DemoControlsTab extends ConsumerWidget {
  const _DemoControlsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(demoSettingsProvider);
    void set(DemoSettings Function(DemoSettings s) change) => ref.read(demoSettingsProvider.notifier).update(change);

    return ListView(
      padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, 0, RidoSpacing.gutter, RidoSpacing.xxl),
      children: [
        DemoGroup(title: 'Booking', children: [
          DemoSwitchTile(
            icon: Symbols.person_search_rounded,
            title: 'No drivers nearby',
            explanation: 'Searching for a driver ends on S-01.',
            value: s.noDrivers,
            onChanged: (v) => set((s) => s.copyWith(noDrivers: v)),
          ),
          DemoSwitchTile(
            icon: Symbols.cancel_rounded,
            title: 'Driver cancels',
            explanation: 'The assigned driver cancels (S-02), then Rido re-searches.',
            value: s.driverCancels,
            onChanged: (v) => set((s) => s.copyWith(driverCancels: v)),
          ),
        ]),
        DemoGroup(title: 'Device and data', children: [
          DemoSwitchTile(
            icon: Symbols.wifi_off_rounded,
            title: 'Offline mode',
            explanation: 'Data screens show No internet (S-04).',
            value: s.offline,
            onChanged: (v) => set((s) => s.copyWith(offline: v)),
          ),
          DemoSwitchTile(
            icon: Symbols.location_off_rounded,
            title: 'Location denied',
            explanation: 'Location permission is refused (S-05).',
            value: s.locationDenied,
            onChanged: (v) => set((s) => s.copyWith(locationDenied: v)),
          ),
          DemoSwitchTile(
            icon: Symbols.wrong_location_rounded,
            title: 'Outside service area',
            explanation: 'Your location is outside Coimbatore (S-08).',
            value: s.outsideServiceArea,
            onChanged: (v) => set((s) => s.copyWith(outsideServiceArea: v)),
          ),
          DemoSwitchTile(
            icon: Symbols.history_rounded,
            title: 'Empty activity',
            explanation: 'Activity has no trips yet (S-06).',
            value: s.emptyActivity,
            onChanged: (v) => set((s) => s.copyWith(emptyActivity: v)),
          ),
          DemoSwitchTile(
            icon: Symbols.hourglass_top_rounded,
            title: 'Slow loading',
            explanation: 'Data takes 3 s to load and shows skeletons (S-07).',
            value: s.slowLoading,
            onChanged: (v) => set((s) => s.copyWith(slowLoading: v)),
          ),
        ]),
        DemoGroup(title: 'Simulation', children: [
          DemoSwitchTile(
            icon: Symbols.fast_forward_rounded,
            title: 'Fast mode',
            explanation: 'Every simulated timer runs 3× faster.',
            value: s.fastMode,
            onChanged: (v) => set((s) => s.copyWith(fastMode: v)),
          ),
          RidoListTile(
            icon: Symbols.restart_alt_rounded,
            title: 'Reset all seed data',
            subtitle: 'Restores trips, profile, places and every switch',
            destructive: true,
            showChevron: false,
            onTap: () => _reset(context, ref),
          ),
        ]),
      ],
    );
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final ok = await showRidoConfirm(
      context,
      title: 'Reset all seed data?',
      message: 'Trips, profile, saved places and every demo switch go back to the seed values.',
      confirmLabel: 'Reset',
      cancelLabel: 'Cancel',
      destructive: true,
      icon: Symbols.restart_alt_rounded,
    );
    if (!ok || !context.mounted) return;
    resetAllSeedData(ref);
    ref
      ..invalidate(rideFlowProvider)
      ..invalidate(parcelFlowProvider)
      ..invalidate(passengerProfileProvider)
      ..invalidate(tripHistoryProvider);
    showRidoSnack(context, 'Seed data reset', success: true);
  }
}
