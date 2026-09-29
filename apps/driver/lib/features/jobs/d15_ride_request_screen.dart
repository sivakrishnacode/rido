import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

import '../../router/routes.dart';
import 'widgets/request_flow.dart';

/// D-15 Incoming ride request: the request card(s) (see [RequestStackView]): fare and ₹/km, pickup and trip, swipen/// to accept → D-16, ✕ / back / timeout → the next open request, else D-14 (timeout shows the S-11 banner).
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
    listenForRequests();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) decline();
      },
      child: requestView(delivery: false),
    );
  }
}
