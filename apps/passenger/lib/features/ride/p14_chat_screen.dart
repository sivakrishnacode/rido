import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../state/parcel_flow.dart';
import '../../state/ride_flow.dart';

/// P-14 Chat with the driver (masked number). [forParcel] shows the goods driver (PP-08 Chat);
/// messages always go through the ride flow's chat, which sends a seeded reply after 2 s.
class P14ChatScreen extends ConsumerWidget {
  const P14ChatScreen({super.key, this.forParcel = false, this.showcase = false});

  final bool forParcel;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  /// "Honda Activa" → "Activa", "Bajaj Maxima Cargo" → "Maxima Cargo".
  static String _shortModel(String model) {
    final parts = model.split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : model;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(rideFlowProvider);
    final parcel = forParcel ? ref.watch(parcelFlowProvider) : null;
    final driver = parcel?.driver ?? ride.driver;

    final String status;
    if (parcel != null) {
      status = switch (parcel.phase) {
        ParcelPhase.atPickup => 'at your pickup',
        ParcelPhase.inTransit => '${parcel.etaMin} min to drop',
        ParcelPhase.delivered => 'delivered',
        ParcelPhase.assigned => 'arriving in ${parcel.etaMin.clamp(1, 99)} min',
        _ => 'arriving in 4 min',
      };
    } else {
      status = switch (ride.phase) {
        RidePhase.arrived => 'waiting at your pickup',
        RidePhase.inProgress => '${ride.etaMin} min to drop',
        RidePhase.completed => 'trip completed',
        _ => 'arriving in ${showcase ? 3 : ride.etaMin.clamp(1, 99)} min',
      };
    }
    final vehicleText = '${driver.vehicleColor} ${_shortModel(driver.vehicleModel)}'.trim();

    return ChatScaffold(
      peerName: driver.name,
      peerInitials: driver.initials,
      messages: ride.chat,
      quickReplies: ref.read(rideRepositoryProvider).quickReplies,
      onSend: (text) => ref.read(rideFlowProvider.notifier).sendChat(text),
      onCall: () => showRidoSnack(context, 'Calling ${driver.firstName} (number hidden)'),
      stripIcon: driver.vehicleKind.icon,
      stripText: '$vehicleText · ${driver.plate} · $status',
    );
  }
}
