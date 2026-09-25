import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../state/driver_account.dart';
import '../../state/driver_session.dart';
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
        appBar: RidoAppBar.driver(
          title: 'Design gallery',
          showBack: true,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: RidoColors.navy300,
            indicatorColor: RidoColors.coral500,
            dividerColor: RidoColors.navy700,
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
        DemoGroup(title: 'Plan and account', children: [
          DemoChoiceTile(
            icon: Symbols.workspace_premium_rounded,
            title: 'Plan status',
            explanation: 'Home and Plan show this subscription state (D-24, D-25).',
            child: RidoSegmented<PlanStatus>(
              options: const [PlanStatus.trial, PlanStatus.active, PlanStatus.grace, PlanStatus.expired],
              labelOf: (p) => p == PlanStatus.trial ? 'Trial' : p.label,
              selected: s.planStatus,
              onChanged: (p) => set((s) => s.copyWith(planStatus: p)),
            ),
          ),
          DemoSwitchTile(
            icon: Symbols.gpp_bad_rounded,
            title: 'Reject KYC',
            explanation: 'The application review ends on KYC rejected (S-09).',
            value: s.rejectKyc,
            onChanged: (v) => set((s) => s.copyWith(rejectKyc: v)),
          ),
          DemoSwitchTile(
            icon: Symbols.block_rounded,
            title: 'Account on hold',
            explanation: 'Home is replaced by Account on hold (S-10).',
            value: s.accountOnHold,
            onChanged: (v) => set((s) => s.copyWith(accountOnHold: v)),
          ),
          DemoSwitchTile(
            icon: Symbols.credit_card_off_rounded,
            title: 'Fail next payment',
            explanation: 'The next UPI Autopay payment fails (S-14).',
            value: s.failNextPayment,
            onChanged: (v) => set((s) => s.copyWith(failNextPayment: v)),
          ),
        ]),
        DemoGroup(title: 'Work', children: [
          DemoChoiceTile(
            icon: Symbols.work_rounded,
            title: 'Work type',
            explanation: 'Online requests are rides (D-15) or deliveries (D-20).',
            child: RidoSegmented<WorkType>(
              options: WorkType.values,
              labelOf: (w) => w == WorkType.rides ? 'Rides' : 'Deliveries',
              selected: s.workType,
              onChanged: (w) => set((s) => s.copyWith(workType: w)),
            ),
          ),
          DemoSwitchTile(
            icon: Symbols.location_disabled_rounded,
            title: 'GPS lost',
            explanation: 'Home shows the GPS weak banner (S-16).',
            value: s.gpsLost,
            onChanged: (v) => set((s) => s.copyWith(gpsLost: v)),
          ),
          DemoSwitchTile(
            icon: Symbols.account_balance_wallet_rounded,
            title: 'Empty earnings',
            explanation: 'Earnings has no trips yet (S-15).',
            value: s.emptyEarnings,
            onChanged: (v) => set((s) => s.copyWith(emptyEarnings: v)),
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
            subtitle: 'Restores earnings, plan, KYC, profile and every switch',
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
      message: 'Earnings, plan, KYC, profile and every demo switch go back to the seed values.',
      confirmLabel: 'Reset',
      cancelLabel: 'Cancel',
      destructive: true,
      icon: Symbols.restart_alt_rounded,
    );
    if (!ok || !context.mounted) return;
    resetAllSeedData(ref);
    ref
      ..invalidate(driverSessionProvider)
      ..invalidate(planProvider)
      ..invalidate(kycProvider)
      ..invalidate(driverProfileProvider)
      ..invalidate(signupProvider)
      ..invalidate(earningsProvider);
    showRidoSnack(context, 'Seed data reset', success: true);
  }
}
