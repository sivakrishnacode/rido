import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

import 'widgets/request_flow.dart';

/// D-20 Incoming delivery request: the same cards as D-15 for goods, with the parcel type, weight and who pays.n/// Swipe to accept → D-21.
class D20DeliveryRequestScreen extends ConsumerStatefulWidget {
  const D20DeliveryRequestScreen({super.key, this.showcase = false, this.sample});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  /// Design gallery: the request shown (default: the parcel).
  final RideRequest? sample;

  @override
  ConsumerState<D20DeliveryRequestScreen> createState() => _D20DeliveryRequestScreenState();
}

class _D20DeliveryRequestScreenState extends ConsumerState<D20DeliveryRequestScreen> with RequestFlow {
  @override
  bool get showcase => widget.showcase;

  @override
  RideRequest get seed => widget.sample ?? Seed.deliveryRequest;


  @override
  Widget build(BuildContext context) {
    listenForRequests();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) decline();
      },
      child: requestView(delivery: true),
    );
  }
}
