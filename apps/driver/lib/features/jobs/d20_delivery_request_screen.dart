import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_session.dart';
import '../../state/live_helpers.dart';
import 'widgets/job_common.dart';
import 'widgets/request_layout.dart';

/// D-20 Incoming delivery request: same takeover as D-15 for goods ("₹180 · 3-wheeler
/// delivery"), with the parcel type, weight and who pays. Accept → D-21.
class D20DeliveryRequestScreen extends ConsumerStatefulWidget {
  const D20DeliveryRequestScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D20DeliveryRequestScreen> createState() => _D20DeliveryRequestScreenState();
}

class _D20DeliveryRequestScreenState extends ConsumerState<D20DeliveryRequestScreen> {
  late final RideRequest _r = ref.read(driverSessionProvider).incoming ?? Seed.deliveryRequest;
  bool _handled = false;

  late final Duration _countdown = ref.read(driverSessionProvider.notifier).incomingCountdown;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    if (!widget.showcase && ref.read(isLiveApiProvider)) HapticFeedback.heavyImpact();
  }

  /// Live API: accepting can fail when the offer went to someone else; the card closes with the reason.
  Future<void> _accept() async {
    if (_handled) return;
    if (widget.showcase) {
      context.push(Routes.delivery);
      return;
    }
    _handled = true;
    setState(() => _accepting = true);
    try {
      await ref.read(driverSessionProvider.notifier).acceptRequest();
    } on Exception catch (e) {
      if (!mounted) return;
      showRidoSnack(context, userMessage(e));
      popOrHome(context);
      return;
    }
    if (mounted) context.pushReplacement(Routes.delivery);
  }

  void _decline() {
    if (_handled) return;
    _handled = true;
    if (!widget.showcase) ref.read(driverSessionProvider.notifier).declineRequest();
    popOrHome(context);
  }

  void _timeout() {
    if (_handled || widget.showcase || !mounted) return;
    _handled = true;
    ref.read(driverSessionProvider.notifier).requestTimedOut();
    popOrHome(context);
  }

  static IconData _categoryIcon(ParcelCategory? c) => switch (c) {
        ParcelCategory.documents => Symbols.description_rounded,
        ParcelCategory.food => Symbols.lunch_dining_rounded,
        ParcelCategory.clothes => Symbols.checkroom_rounded,
        ParcelCategory.electronics => Symbols.devices_rounded,
        ParcelCategory.household => Symbols.chair_rounded,
        ParcelCategory.furniture => Symbols.weekend_rounded,
        _ => Symbols.package_2_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    if (!widget.showcase) {
      // Closed from elsewhere (went offline, the request was withdrawn): leave the card.
      ref.listen(driverSessionProvider.select((s) => s.incoming?.id), (prev, next) {
        if (next == null && !_handled && mounted) {
          _handled = true;
          popOrHome(context);
        }
      });
    }
    final parcel = _r.parcel;
    final payer = parcel?.payer == ParcelPayer.receiver ? 'Receiver' : 'Sender';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _decline();
      },
      child: RequestTakeover(
        title: 'New delivery request',
        tag: RequestVehicleTag(vehicle: _r.vehicle, showIcon: false),
        fare: _r.fare,
        fareCaption: '${_r.vehicle.label} delivery',
        countdown: widget.showcase ? ref.read(simTimingProvider)(SimTimings.requestCountdown) : _countdown,
        running: !widget.showcase && !_accepting,
        onTimeout: _timeout,
        below: Container(
          padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l, vertical: RidoSpacing.s),
          decoration: const BoxDecoration(color: RidoColors.navy900, borderRadius: RidoRadii.pillRadius),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Symbols.person_pin_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: RidoSpacing.s),
            Text('Paid by: $payer', style: t.bodySemibold.copyWith(color: Colors.white)),
          ]),
        ),
        details: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l, vertical: RidoSpacing.m),
            decoration: const BoxDecoration(color: RidoColors.coral50, borderRadius: RidoRadii.cardRadius),
            child: Row(children: [
              Icon(_categoryIcon(parcel?.category), color: RidoColors.coral600),
              const SizedBox(width: RidoSpacing.m),
              Expanded(
                child: Text(parcel?.category.label ?? 'Parcel',
                    style: t.bodySemibold, overflow: TextOverflow.ellipsis),
              ),
              if (parcel != null) Text(parcel.weight.label, style: t.bodyMedium.copyWith(color: RidoColors.navy700)),
            ]),
          ),
          const SizedBox(height: RidoSpacing.l),
          RequestRoute(request: _r, pickupTitle: _r.pickup.fullAddress.replaceAll(' Rd', ' Road').split(', ').take(2).join(', ')),
          const SizedBox(height: RidoSpacing.l),
          Row(children: [
            const Icon(Symbols.front_hand_rounded, size: 18, color: RidoColors.navy500),
            const SizedBox(width: RidoSpacing.s),
            Expanded(child: Text('Sender and receiver load / unload.', style: t.caption.copyWith(fontSize: null))),
          ]),
        ],
        onAccept: _accept,
        accepting: _accepting,
        onDecline: _decline,
      ),
    );
  }
}
