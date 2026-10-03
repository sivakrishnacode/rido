import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../common/showcase.dart';
import '../../common/launch.dart';
import '../../router/routes.dart';
import '../../state/driver_session.dart';
import '../../state/live_helpers.dart';
import '../home/widgets/navy_header.dart';
import 'widgets/job_common.dart';
import 'widgets/job_menu.dart';
import 'widgets/no_show_button.dart';
import 'widgets/shifting_sheet.dart';
import 'widgets/too_far_sheet.dart';
import 'widgets/job_map.dart';
import 'widgets/parcel_photo.dart';

/// D-21 Delivery in progress: stepper Go to pickup → Picked up → Go to drop → Delivered,
/// driven by the session phase. One swipe per step: "Reached pickup", "Picked up",
/// "Reached drop location" (→ D-22a). Back asks before leaving.
/// Live API: "Reached pickup" and "Picked up" are API calls ("Reached drop" is local), Call dials the
/// sender / receiver and Navigate opens Google Maps. A house shift shows the floor and lift at this end, the team to
/// bring and "See items" (the customer's typed list, [showShiftingDetails]).
class D21DeliveryInProgressScreen extends ConsumerStatefulWidget {
  const D21DeliveryInProgressScreen({super.key, this.showcase = false, this.sample, this.samplePhase = JobPhase.toDrop});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  /// Design gallery: the job shown (default: the parcel) and its step.
  final RideRequest? sample;
  final JobPhase samplePhase;

  @override
  ConsumerState<D21DeliveryInProgressScreen> createState() =>
      _D21DeliveryInProgressScreenState();
}

class _D21DeliveryInProgressScreenState
    extends ConsumerState<D21DeliveryInProgressScreen> {
  static const _steps = [
    'Go to pickup',
    'Picked up',
    'Go to drop',
    'Delivered',
  ];
  RideRequest get _job =>
      ref.read(driverSessionProvider).job ??
      widget.sample ??
      Seed.deliveryRequest;

  /// Phase used when there is no live job (showcase / opened directly): the D-21 frame.
  late JobPhase _localPhase = widget.samplePhase;
  late final bool _api = !widget.showcase && ref.read(isLiveApiProvider);
  bool _busy = false;

  /// ⋮ → Cancel (before the pickup) and the no-show cancel at the pickup: reason → the API → Home.
  Future<void> _cancel({CancelCode? code}) async {
    if (widget.showcase) return showTtSnack(context, kPreviewNote);
    final noun = _job.isShifting ? 'job' : 'delivery';
    final reason =
        code ??
        await CancelReasonDialog.show(
          context,
          reasons: CancelCode.forDriver,
          noun: noun,
        );
    if (reason == null || !mounted) return;
    if (code != null) {
      final ok = await showTtConfirm(
        context,
        title: "Sender didn't come?",
        message: "Cancel this $noun as a no-show. It won't count against you.",
        confirmLabel: 'Cancel $noun',
        cancelLabel: 'Keep waiting',
        icon: Symbols.person_off_rounded,
      );
      if (!ok || !mounted) return;
    }
    if (ref.read(driverSessionProvider).job != null) {
      setState(() => _busy = true);
      try {
        await ref.read(driverSessionProvider.notifier).cancelJob(code: reason);
      } on Exception catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        showTtSnack(context, userMessage(e));
        return;
      }
      if (!mounted) return;
    }
    showTtSnack(
      context,
      '${_job.isShifting ? 'Job' : 'Delivery'} cancelled · ${reason.label}',
    );
    context.go(Routes.home);
  }

  Future<void> _advance(bool live, JobPhase phase) async {
    if (_busy) return;
    final c = ref.read(driverSessionProvider.notifier);
    Future<void> step(Future<void> Function() action) async {
      setState(() => _busy = true);
      try {
        await action();
      } on Exception catch (e) {
        if (mounted) showTtSnack(context, userMessage(e));
      }
      if (mounted) setState(() => _busy = false);
    }

    switch (phase) {
      case JobPhase.toPickup:
        // Far from the pickup the API asks for a reason (TooFarSheet) first.
        live
            ? await step(() => runWithFarCheck(context, (r) => c.arrivedAtPickup(farReason: r), target: _job.pickup.location))
            : setState(() => _localPhase = JobPhase.atPickup);
      case JobPhase.atPickup:
        live ? await step(c.startTrip) : setState(() => _localPhase = JobPhase.toDrop);
      default:
        if (widget.showcase) return showTtSnack(context, kPreviewNote);
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
    final waiting = live ? session.waiting : null;
    final toDrop = phase == JobPhase.toDrop || phase == JobPhase.atDrop || phase == JobPhase.collect;
    final stepIndex = switch (phase) {
      JobPhase.none || JobPhase.toPickup => 0,
      JobPhase.atPickup => 1,
      JobPhase.toDrop => 2,
      _ => 3,
    };
    final mode = travelModeFor(_job.vehicle);
    final fallbackRoute = toDrop
        ? roadPath(_job.pickup.location, _job.drop.location, mode: mode)
        : roadPath(Seed.driverHome, _job.pickup.location, bend: -0.2, mode: mode);
    final route = live && session.route.isNotEmpty ? session.route : fallbackRoute;
    final eta = live ? session.etaMin : (toDrop ? 13 : _job.pickupEtaMin);
    final parcel = _job.parcel;
    final place = toDrop ? _job.drop : _job.pickup;
    final contactName = toDrop ? (parcel?.receiverName ?? _job.customerName) : (parcel?.senderName ?? 'Sender');
    final contactPhone = toDrop ? (parcel?.receiverPhone ?? _job.customerPhone) : (parcel?.senderPhone ?? _job.customerPhone);
    final contactNote = toDrop
        ? (parcel?.dropNote.isNotEmpty ?? false ? parcel!.dropNote : 'House 14, near walking track')
        : (parcel?.pickupNote.isNotEmpty ?? false ? parcel!.pickupNote : place.address);
    final byReceiver = parcel?.payer != ParcelPayer.sender;
    final shift = _job.shifting;
    final helpers = shift?.lines?.helperCount;
    // Live API: early hint when the GPS is already outside the stop's radius (the API decides).
    final farM = _api && (phase == JobPhase.toPickup || phase == JobPhase.toDrop)
        ? ref.read(driverSessionProvider.notifier).metresTo(place.location)
        : null;
    final radius = toDrop ? kDropRadiusM : kPickupRadiusM;
    final far = farM != null && farM > radius ? ' · ${formatMetres(farM)} away' : '';
    final swipeLabel = switch (phase) {
      JobPhase.none || JobPhase.toPickup => 'Reached pickup$far',
      JobPhase.atPickup => 'Picked up',
      _ => 'Reached drop$far',
    };

    return PopScope(
      canPop: !live,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) confirmLeaveJob(context, delivery: true);
      },
      child: Scaffold(
        backgroundColor: TtColors.background,
        body: Column(
          children: [
            NavyHeader(
              padding: const EdgeInsets.fromLTRB(
                TtSpacing.gutter,
                TtSpacing.s,
                TtSpacing.gutter,
                TtSpacing.m,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          phase == JobPhase.atPickup
                              ? (shift == null
                                    ? 'Load the parcel'
                                    : 'Load up${helpers == null ? '' : ' · $helpers helpers'}')
                              : (toDrop ? 'Go to drop' : 'Go to pickup'),
                          style: t.bodySmall.copyWith(color: Colors.white70),
                        ),
                        Text(
                          phase == JobPhase.atPickup
                              ? place.name
                              : '${place.name} · $eta min',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TtTextStyles.tabular(
                            t.h2.copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: TtSpacing.s),
                  JobMoreMenu(
                    onHelp: () => widget.showcase
                        ? showTtSnack(context, kPreviewNote)
                        : context.push(Routes.help),
                    // Before the pickup only: once loaded, the job is finished at the drop.
                    onCancel: toDrop ? null : _cancel,
                    cancelLabel: shift == null
                        ? 'Cancel delivery'
                        : 'Cancel job',
                  ),
                  NavigatePill(
                    onDark: true,
                    onPressed: () => _api
                        ? openNavigation(context, place.location)
                        : showTtSnack(context, 'Opening Google Maps'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LiveVehicleMap(
                key: ValueKey('delivery-map-$toDrop'),
                vehicleType: _job.vehicle.mapType,
                fixedPosition: live
                    ? null
                    : pointAlong(route, phase == JobPhase.atPickup ? 1 : 0.3),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  StepperTimeline(steps: _steps, currentIndex: stepIndex),
                  const Divider(height: TtSpacing.xl),
                  Row(
                    children: [
                      TtAvatar(initials: initialsOf(contactName), size: 52),
                      const SizedBox(width: TtSpacing.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contactName,
                              style: t.h2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              shift == null
                                  ? contactNote
                                  : (toDrop
                                        ? floorLabel(
                                            shift.dropFloor,
                                            shift.dropLift,
                                          )
                                        : floorLabel(
                                            shift.pickupFloor,
                                            shift.pickupLift,
                                          )),
                              style: t.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: TtSpacing.s),
                      RoundIconButton(
                        icon: Symbols.chat_rounded,
                        tooltip: 'Chat with ${_job.customerName}',
                        size: 48,
                        onPressed: unlessShowcase(
                          context,
                          widget.showcase,
                          () => context.push(Routes.chat),
                        )!,
                      ),
                      const SizedBox(width: TtSpacing.s),
                      TtButton(
                        label: 'Call',
                        icon: Symbols.call_rounded,
                        expand: false,
                        semanticLabel: 'Call $contactName',
                        onPressed: () => _api
                            ? dialNumber(
                                context,
                                contactPhone,
                                name: contactName,
                              )
                            : showTtSnack(
                                context,
                                'Calling ${contactName.split(' ').first} (number hidden)',
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: TtSpacing.m),
                  Wrap(
                    spacing: TtSpacing.s,
                    runSpacing: TtSpacing.s,
                    children: [
                      if (shift != null) ...[
                        _Chip(
                          icon: Symbols.home_rounded,
                          text: [
                            shift.homeSize.label,
                            if (helpers != null) '$helpers helpers',
                          ].join(' · '),
                          bg: TtColors.coral50,
                          fg: TtColors.coral700,
                        ),
                        _Chip(
                          icon: Symbols.checklist_rounded,
                          text: 'See ${shift.items.length} items',
                          bg: TtColors.infoTint,
                          fg: TtColors.navy900,
                          onTap: () => showShiftingDetails(context, _job),
                        ),
                      ] else if (parcel != null)
                        _Chip(
                          icon: Symbols.checkroom_rounded,
                          text:
                              '${parcel.category.label} · ${parcel.weight.label}',
                          bg: TtColors.inputBg,
                          fg: TtColors.navy700,
                        ),
                      _Chip(
                        text: shift != null
                            ? 'Collect ${formatInr(_job.fare)} after the move'
                            : byReceiver
                            ? 'Collect ${formatInr(_job.fare)} from receiver'
                            : 'Collect ${formatInr(_job.fare)} from sender',
                        bg: TtColors.warningTint,
                        fg: TtColors.warningText,
                      ),
                    ],
                  ),
                  if (phase == JobPhase.atPickup && waiting != null) ...[
                    const SizedBox(height: TtSpacing.m),
                    WaitingTimerChip(terms: waiting, isTicking: live),
                  ],
                  // At the pickup and nobody came: after the wait, cancel as a no-show (doesn't count against the driver).
                  if (live && phase == JobPhase.atPickup) ...[
                    const SizedBox(height: TtSpacing.s),
                    NoShowButton(
                      noShowAt: session.noShowAt,
                      who: 'Sender',
                      enabled: !_busy,
                      onCancel: () => _cancel(code: CancelCode.passengerNoShow),
                    ),
                  ],
                  const SizedBox(height: TtSpacing.l),
                  if (_api && _job.parcelPhotoFile != null) ...[
                    const SizedBox(height: TtSpacing.m),
                    ParcelPhoto(tripId: _job.id),
                  ],
                  SwipeToConfirm(
                    key: ValueKey('swipe-$phase'),
                    label: swipeLabel,
                    enabled: !_busy,
                    onConfirmed: () => _advance(live, phase),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.bg, required this.fg, this.icon, this.onTap});
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: bg,
        borderRadius: TtRadii.pillRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: TtRadii.pillRadius,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: TtSpacing.m, vertical: onTap == null ? 6 : 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 6)],
              Flexible(child: Text(text, style: context.type.bodySmallMedium.copyWith(color: fg, fontWeight: FontWeight.w600))),
              if (onTap != null) ...[const SizedBox(width: 2), Icon(Symbols.chevron_right_rounded, size: 18, color: fg)],
            ]),
          ),
        ),
      );
}
