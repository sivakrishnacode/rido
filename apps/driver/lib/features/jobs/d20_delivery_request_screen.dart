import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import 'widgets/request_flow.dart';
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

class _D20DeliveryRequestScreenState extends ConsumerState<D20DeliveryRequestScreen> with RequestFlow {
  @override
  bool get showcase => widget.showcase;

  @override
  RideRequest get seed => Seed.deliveryRequest;

  @override
  String get acceptRoute => Routes.delivery;

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
    listenForRequests();
    // Two or more open requests: compare them side by side.
    final stack = stackView(delivery: true);
    if (stack != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) decline();
        },
        child: stack,
      );
    }
    final r0 = request;
    final parcel = r0.parcel;
    final payer = parcel?.payer == ParcelPayer.receiver ? 'Receiver' : 'Sender';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) decline();
      },
      child: RequestTakeover(
        key: ValueKey(r0.id),
        title: 'New delivery request',
        tag: RequestVehicleTag(vehicle: r0.vehicle, showIcon: false),
        fare: r0.fare,
        fareCaption: '${r0.vehicle.label} delivery',
        countdown: countdown,
        running: running,
        onTimeout: timeout,
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
          RequestRoute(request: r0, pickupTitle: r0.pickup.fullAddress.replaceAll(' Rd', ' Road').split(', ').take(2).join(', ')),
          const SizedBox(height: RidoSpacing.l),
          Row(children: [
            const Icon(Symbols.front_hand_rounded, size: 18, color: RidoColors.navy500),
            const SizedBox(width: RidoSpacing.s),
            Expanded(child: Text('Sender and receiver load / unload.', style: t.caption.copyWith(fontSize: null))),
          ]),
        ],
        onAccept: accept,
        accepting: accepting,
        onDecline: decline,
      ),
    );
  }
}
