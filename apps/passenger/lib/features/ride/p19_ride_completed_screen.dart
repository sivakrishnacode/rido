import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/ride_flow.dart';
import '../states/widgets/state_orb.dart';
import 'p11_fare_details_sheet.dart';
import 'widgets/trip_widgets.dart';

/// P-19 Ride completed · pay the driver directly: "You've arrived!", the hero fare, the UPI QR
/// hint, the trip summary with fare details, the 0% commission line and "Done, rate your ride".
class P19RideCompletedScreen extends ConsumerStatefulWidget {
  const P19RideCompletedScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P19RideCompletedScreen> createState() => _P19RideCompletedScreenState();
}

class _P19RideCompletedScreenState extends ConsumerState<P19RideCompletedScreen> {
  /// Arrival time, fixed when the screen opens.
  late final DateTime _arrivedAt = widget.showcase ? DateTime(2026, 9, 24, 15, 42) : RidoClock.now();

  void _done() => context.push(Routes.rateDriver);

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final ride = ref.watch(rideFlowProvider);
    final driver = ride.driver.firstName;
    final quote = ride.quote;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        backgroundColor: RidoColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                  children: [
                    const Center(
                      child: StateOrb(
                        size: 144,
                        inner: true,
                        accentDots: true,
                        label: 'You have arrived',
                        child: Icon(Symbols.where_to_vote_rounded, fill: 1, size: 64, color: RidoColors.coral500),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text("You've arrived!", style: t.display, textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(
                      '${ride.drop.name} · ${formatTime(_arrivedAt)}',
                      style: RidoTextStyles.tabular(t.body.copyWith(color: RidoColors.navy500)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(formatInr(quote.total), style: t.hero, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      'Pay $driver directly: Cash or UPI',
                      style: t.bodyMedium.copyWith(color: RidoColors.navy700, fontSize: 17),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(color: RidoColors.inputBg, borderRadius: RidoRadii.cardRadius),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(color: RidoColors.surface, borderRadius: RidoRadii.cardRadius),
                            child: const Icon(Symbols.qr_code_scanner_rounded, color: RidoColors.navy900),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text("Scan $driver's UPI QR on his phone, or pay cash",
                                style: t.body.copyWith(color: RidoColors.navy900)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    RidoCard(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${shortPlaceName(ride.pickup.name)} → ${shortPlaceName(ride.drop.name)}',
                                  style: t.bodyMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${quote.distanceKm.toStringAsFixed(1)} km · ${quote.durationMin} min · ${ride.vehicle.label}',
                                  style: RidoTextStyles.tabular(t.bodySmall.copyWith(color: RidoColors.navy500)),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => P11FareDetailsSheet.show(context),
                            child: const Text('Details'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: const BoxDecoration(color: RidoColors.coral50, borderRadius: RidoRadii.pillRadius),
                          child: Text('0%',
                              style: t.caption.copyWith(color: RidoColors.coral600, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$driver keeps the full ${formatInr(quote.total)}. Rido takes 0%.',
                            style: t.body.copyWith(color: RidoColors.navy700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: RidoButton(label: 'Done, rate your ride', onPressed: _done),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
