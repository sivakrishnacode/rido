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

/// D-21 Delivery in progress: stepper Go to pickup → Picked up → Go to drop → Delivered,
/// driven by the session phase. One swipe per step: "Reached pickup", "Picked up",
/// "Reached drop location" (→ D-22a). Back asks before leaving.
class D21DeliveryInProgressScreen extends ConsumerStatefulWidget {
  const D21DeliveryInProgressScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D21DeliveryInProgressScreen> createState() => _D21DeliveryInProgressScreenState();
}

class _D21DeliveryInProgressScreenState extends ConsumerState<D21DeliveryInProgressScreen> {
  static const _steps = ['Go to pickup', 'Picked up', 'Go to drop', 'Delivered'];

  late final RideRequest _job = ref.read(driverSessionProvider).job ?? Seed.deliveryRequest;

  /// Phase used when there is no live job (showcase / opened directly): the D-21 frame.
  JobPhase _localPhase = JobPhase.toDrop;

  void _advance(bool live, JobPhase phase) {
    final c = ref.read(driverSessionProvider.notifier);
    switch (phase) {
      case JobPhase.toPickup:
        live ? c.arrivedAtPickup() : setState(() => _localPhase = JobPhase.atPickup);
      case JobPhase.atPickup:
        live ? c.startTrip() : setState(() => _localPhase = JobPhase.toDrop);
      default:
        if (live) {
          c.reachedDrop();
          context.pushReplacement(Routes.deliveryOtp);
        } else {
          context.push(Routes.deliveryOtp);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final session = ref.watch(driverSessionProvider);
    final live = !widget.showcase && session.job != null;
    final phase = live ? session.phase : _localPhase;
    final toDrop = phase == JobPhase.toDrop || phase == JobPhase.atDrop || phase == JobPhase.collect;
    final stepIndex = switch (phase) {
      JobPhase.none || JobPhase.toPickup => 0,
      JobPhase.atPickup => 1,
      JobPhase.toDrop => 2,
      _ => 3,
    };
    final fallbackRoute = toDrop
        ? roadPath(_job.pickup.location, _job.drop.location)
        : roadPath(Seed.driverHome, _job.pickup.location, bend: -0.2);
    final route = live && session.route.isNotEmpty ? session.route : fallbackRoute;
    final eta = live ? session.etaMin : (toDrop ? 13 : _job.pickupEtaMin);
    final parcel = _job.parcel;
    final place = toDrop ? _job.drop : _job.pickup;
    final contactName = toDrop ? (parcel?.receiverName ?? _job.customerName) : (parcel?.senderName ?? 'Sender');
    final contactNote = toDrop
        ? (parcel?.dropNote.isNotEmpty ?? false ? parcel!.dropNote : 'House 14, near walking track')
        : (parcel?.pickupNote.isNotEmpty ?? false ? parcel!.pickupNote : place.address);
    final byReceiver = parcel?.payer != ParcelPayer.sender;
    final swipeLabel = switch (phase) {
      JobPhase.none || JobPhase.toPickup => 'Reached pickup',
      JobPhase.atPickup => 'Picked up',
      _ => 'Reached drop location',
    };

    return PopScope(
      canPop: !live,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) confirmLeaveJob(context, delivery: true);
      },
      child: Scaffold(
        backgroundColor: RidoColors.background,
        body: Column(
          children: [
            NavyHeader(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.s, RidoSpacing.gutter, RidoSpacing.m),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      phase == JobPhase.atPickup ? 'Load the parcel' : (toDrop ? 'Go to drop' : 'Go to pickup'),
                      style: t.bodySmall.copyWith(color: Colors.white70),
                    ),
                    Text(
                      phase == JobPhase.atPickup ? place.name : '${place.name} · $eta min',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RidoTextStyles.tabular(t.h2.copyWith(color: Colors.white)),
                    ),
                  ]),
                ),
                const SizedBox(width: RidoSpacing.s),
                NavigatePill(onDark: true, onPressed: () => showRidoSnack(context, 'Opening Google Maps')),
              ]),
            ),
            Expanded(
              child: LiveVehicleMap(
                key: ValueKey('delivery-map-$toDrop'),
                vehicleType: _job.vehicle.mapType,
                fixedPosition: live ? null : pointAlong(route, phase == JobPhase.atPickup ? 1 : 0.3),
                pickup: toDrop ? null : _job.pickup.location,
                drop: toDrop ? _job.drop.location : null,
                route: route,
                fitPoints: route,
                fitPadding: const EdgeInsets.fromLTRB(56, 72, 56, 72),
                centerOnVehicle: false,
              ),
            ),
            BottomPanel(
              handle: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                StepperTimeline(steps: _steps, currentIndex: stepIndex),
                const Divider(height: RidoSpacing.xl),
                Row(children: [
                  RidoAvatar(initials: initialsOf(contactName), size: 52),
                  const SizedBox(width: RidoSpacing.m),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(contactName, style: t.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(contactNote, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  const SizedBox(width: RidoSpacing.s),
                  RidoButton(
                    label: 'Call',
                    icon: Symbols.call_rounded,
                    expand: false,
                    semanticLabel: 'Call $contactName',
                    onPressed: () => showRidoSnack(context, 'Calling ${contactName.split(' ').first} (number hidden)'),
                  ),
                ]),
                const SizedBox(height: RidoSpacing.m),
                Wrap(spacing: RidoSpacing.s, runSpacing: RidoSpacing.s, children: [
                  if (parcel != null)
                    _Chip(
                      icon: Symbols.checkroom_rounded,
                      text: '${parcel.category.label} · ${parcel.weight.label}',
                      bg: RidoColors.inputBg,
                      fg: RidoColors.navy700,
                    ),
                  _Chip(
                    text: byReceiver ? 'Collect ${formatInr(_job.fare)} from receiver' : 'Collect ${formatInr(_job.fare)} from sender',
                    bg: RidoColors.warningTint,
                    fg: RidoColors.warningText,
                  ),
                ]),
                const SizedBox(height: RidoSpacing.l),
                SwipeToConfirm(
                  key: ValueKey('swipe-$phase'),
                  label: swipeLabel,
                  onConfirmed: () => _advance(live, phase),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.bg, required this.fg, this.icon});
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.m, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: RidoRadii.pillRadius),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 6)],
          Flexible(child: Text(text, style: context.type.bodySmallMedium.copyWith(color: fg, fontWeight: FontWeight.w600))),
        ]),
      );
}
