import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_session.dart';
import 'widgets/job_common.dart';
import 'widgets/request_layout.dart';

/// D-15 Incoming ride request: coral takeover with a 15 s countdown ring around the fare.
/// Accept → D-16. Decline, back or timeout → D-14 (timeout shows the S-11 banner).
class D15RideRequestScreen extends ConsumerStatefulWidget {
  const D15RideRequestScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D15RideRequestScreen> createState() => _D15RideRequestScreenState();
}

class _D15RideRequestScreenState extends ConsumerState<D15RideRequestScreen> {
  late final RideRequest _r = ref.read(driverSessionProvider).incoming ?? Seed.rideRequest;
  bool _handled = false;

  void _accept() {
    if (_handled) return;
    _handled = true;
    if (widget.showcase) {
      context.push(Routes.pickup);
      _handled = false;
      return;
    }
    ref.read(driverSessionProvider.notifier).acceptRequest();
    context.pushReplacement(Routes.pickup);
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

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _decline();
      },
      child: RequestTakeover(
        title: 'New ride request',
        tag: RequestVehicleTag(vehicle: _r.vehicle),
        fare: _r.fare,
        fareCaption: '${_r.vehicle.label} ride',
        countdown: ref.read(simTimingProvider)(SimTimings.requestCountdown),
        running: !widget.showcase,
        onTimeout: _timeout,
        below: Text('Cash / UPI to you · 100% yours',
            textAlign: TextAlign.center, style: t.body.copyWith(color: Colors.white)),
        details: [
          RequestRoute(request: _r),
          const SizedBox(height: RidoSpacing.xl),
          RequestCustomerCard(name: _r.customerName, rating: _r.customerRating),
        ],
        onAccept: _accept,
        onDecline: _decline,
      ),
    );
  }
}
