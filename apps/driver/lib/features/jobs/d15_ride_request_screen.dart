import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import 'widgets/request_flow.dart';
import 'widgets/request_layout.dart';

/// D-15 Incoming ride request: coral takeover with a 15 s countdown ring around the fare, and chips for any other
/// open requests (tap to switch). Swipe to accept → D-16. Decline, back or timeout → the next open request, else
/// D-14 (timeout shows the S-11 banner).
class D15RideRequestScreen extends ConsumerStatefulWidget {
  const D15RideRequestScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D15RideRequestScreen> createState() => _D15RideRequestScreenState();
}

class _D15RideRequestScreenState extends ConsumerState<D15RideRequestScreen> with RequestFlow {
  @override
  bool get showcase => widget.showcase;

  @override
  RideRequest get seed => Seed.rideRequest;

  @override
  String get acceptRoute => Routes.pickup;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    listenForRequests();
    final r = request;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) decline();
      },
      child: RequestTakeover(
        // A new request in focus: fresh ring and swipe.
        key: ValueKey(r.id),
        title: 'New ride request',
        tag: RequestVehicleTag(vehicle: r.vehicle),
        fare: r.fare,
        fareCaption: '${r.vehicle.label} ride',
        countdown: countdown,
        running: running,
        onTimeout: timeout,
        below: Text('Cash / UPI to you · 100% yours',
            textAlign: TextAlign.center, style: t.body.copyWith(color: Colors.white)),
        stack: stackChips(),
        details: [
          RequestRoute(request: r),
          const SizedBox(height: RidoSpacing.xl),
          RequestCustomerCard(
            name: r.customerName,
            rating: r.customerRating,
            isVerified: r.isCustomerVerified,
            isWomenOnly: r.isWomenOnly,
            bookedBy: r.bookedBy,
          ),
        ],
        onAccept: accept,
        accepting: accepting,
        onDecline: decline,
      ),
    );
  }
}
