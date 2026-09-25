import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_session.dart';
import '../home/widgets/navy_header.dart';
import 'widgets/job_common.dart';
import 'widgets/job_map.dart';

/// D-16 Navigate to pickup: route to the pickup with the moving vehicle, Navigate, passenger
/// call / chat, pickup address card and the "Arrived at pickup" swipe (→ D-17).
/// The overflow menu has Help and Cancel ride (reason dialog → D-14).
class D16NavigateToPickupScreen extends ConsumerStatefulWidget {
  const D16NavigateToPickupScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D16NavigateToPickupScreen> createState() => _D16NavigateToPickupScreenState();
}

class _D16NavigateToPickupScreenState extends ConsumerState<D16NavigateToPickupScreen> {
  static const _cancelReasons = [
    'Passenger not reachable',
    'Passenger asked me to cancel',
    'Pickup is too far',
    'Vehicle problem',
    'Other reason',
  ];

  late final RideRequest _job = ref.read(driverSessionProvider).job ?? Seed.rideRequest;
  late final List<LatLng> _fallbackRoute = roadPath(Seed.driverHome, _job.pickup.location, bend: -0.2);

  bool get _live => !widget.showcase && ref.read(driverSessionProvider).job != null;

  void _arrived() {
    if (_live) ref.read(driverSessionProvider.notifier).arrivedAtPickup();
    if (widget.showcase) {
      context.push(Routes.rideOtp);
    } else {
      context.pushReplacement(Routes.rideOtp);
    }
  }

  Future<void> _cancel() async {
    final reason = await showDialog<String>(context: context, builder: (_) => const _CancelReasonDialog(reasons: _cancelReasons));
    if (reason == null || !mounted) return;
    if (_live) ref.read(driverSessionProvider.notifier).cancelJob();
    showRidoSnack(context, 'Ride cancelled · $reason');
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final session = ref.watch(driverSessionProvider);
    final live = !widget.showcase && session.job != null;
    final route = live && session.route.isNotEmpty ? session.route : _fallbackRoute;
    final eta = live ? session.etaMin : _job.pickupEtaMin;
    final km = _job.pickupEtaMin == 0 ? 0.0 : _job.pickupDistanceKm * eta / _job.pickupEtaMin;

    return PopScope(
      canPop: widget.showcase || !live,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) confirmLeaveJob(context);
      },
      child: Scaffold(
        backgroundColor: RidoColors.background,
        body: Column(
          children: [
            NavyHeader(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.s, RidoSpacing.s, RidoSpacing.m),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Going to pickup', style: t.bodySmall.copyWith(color: Colors.white70)),
                    Text(eta <= 0 ? 'Arriving now' : '$eta min · ${formatKm(km)}',
                        style: RidoTextStyles.tabular(t.h1.copyWith(color: Colors.white))),
                  ]),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More options',
                  icon: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: RidoColors.navy700, shape: BoxShape.circle),
                    child: const Icon(Symbols.more_vert_rounded, color: Colors.white),
                  ),
                  color: RidoColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: RidoRadii.cardRadius),
                  position: PopupMenuPosition.under,
                  onSelected: (v) {
                    if (v == 'help') context.push(Routes.help);
                    if (v == 'cancel') _cancel();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'help',
                      height: 56,
                      child: Row(children: [
                        const Icon(Symbols.support_agent_rounded, color: RidoColors.navy700),
                        const SizedBox(width: RidoSpacing.m),
                        Text('Help', style: t.body),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'cancel',
                      height: 56,
                      child: Row(children: [
                        const Icon(Symbols.cancel_rounded, color: RidoColors.error),
                        const SizedBox(width: RidoSpacing.m),
                        Text('Cancel ride', style: t.body.copyWith(color: RidoColors.error)),
                      ]),
                    ),
                  ],
                ),
              ]),
            ),
            Expanded(
              child: Stack(children: [
                Positioned.fill(
                  child: LiveVehicleMap(
                    vehicleType: _job.vehicle.mapType,
                    fixedPosition: live ? null : pointAlong(route, 0.35),
                    pickup: _job.pickup.location,
                    route: route,
                    fitPoints: route,
                    fitPadding: const EdgeInsets.fromLTRB(56, 72, 56, 96),
                    centerOnVehicle: false,
                  ),
                ),
                Positioned(
                  right: RidoSpacing.gutter,
                  bottom: RidoSpacing.xl,
                  child: NavigatePill(onPressed: () => showRidoSnack(context, 'Opening Google Maps')),
                ),
              ]),
            ),
            BottomPanel(
              handle: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  RidoAvatar(initials: initialsOf(_job.customerName), size: 52),
                  const SizedBox(width: RidoSpacing.m),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(
                          child: Text('${_job.customerName} · ${_job.customerRating.toStringAsFixed(1)}',
                              style: t.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        const Icon(Symbols.star_rounded, fill: 1, size: 20, color: RidoColors.navy900),
                      ]),
                      Text('${formatInr(_job.fare)} · Cash / UPI',
                          style: RidoTextStyles.tabular(t.bodySmall.copyWith(color: RidoColors.navy500))),
                    ]),
                  ),
                  RoundIconButton(
                    icon: Symbols.chat_rounded,
                    tooltip: 'Chat with ${_job.customerName}',
                    onPressed: () => context.push(Routes.chat),
                  ),
                  const SizedBox(width: RidoSpacing.m),
                  RoundIconButton(
                    icon: Symbols.call_rounded,
                    tooltip: 'Call ${_job.customerName}',
                    background: RidoColors.coral600,
                    foreground: Colors.white,
                    onPressed: () => showRidoSnack(context, 'Calling ${_job.customerName} (number hidden)'),
                  ),
                ]),
                const SizedBox(height: RidoSpacing.l),
                RidoCard(
                  child: Row(children: [
                    const PickupDot(),
                    const SizedBox(width: RidoSpacing.m),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_job.pickup.name, style: t.bodySemibold, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(_pickupNote(_job), style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: RidoSpacing.l),
                SwipeToConfirm(label: 'Arrived at pickup', onConfirmed: _arrived),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  static String _pickupNote(RideRequest r) =>
      r.pickup.id == Seed.gandhipuram.id ? 'Gate 2, opposite Annapoorna hotel' : r.pickup.address;
}

/// Radio list of cancel reasons. Returns the chosen reason, or null for "Keep ride".
class _CancelReasonDialog extends StatefulWidget {
  const _CancelReasonDialog({required this.reasons});
  final List<String> reasons;

  @override
  State<_CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<_CancelReasonDialog> {
  String? _reason;

  @override
  Widget build(BuildContext context) => RidoDialog(
        title: 'Why are you cancelling?',
        message: 'Frequent cancellations can lower your rating.',
        icon: Symbols.cancel_rounded,
        destructive: true,
        content: RadioGroup<String>(
          groupValue: _reason,
          onChanged: (v) => setState(() => _reason = v),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final r in widget.reasons)
              RadioListTile<String>(
                value: r,
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(r, style: context.type.body),
              ),
          ]),
        ),
        actions: [
          RidoButton.danger(
            label: 'Cancel ride',
            onPressed: _reason == null ? null : () => Navigator.of(context).pop(_reason),
          ),
          const SizedBox(height: RidoSpacing.xs),
          RidoButton.text(label: 'Keep ride', expand: true, onPressed: () => Navigator.of(context).pop()),
        ],
      );
}
