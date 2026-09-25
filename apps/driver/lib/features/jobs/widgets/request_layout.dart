import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

/// Shared D-15 / D-20 full-screen takeover: coral top area with the countdown ring around
/// the fare, then the job details and a big Accept / small Decline.
class RequestTakeover extends StatelessWidget {
  const RequestTakeover({
    super.key,
    required this.title,
    required this.tag,
    required this.fare,
    required this.fareCaption,
    required this.countdown,
    required this.running,
    required this.onTimeout,
    required this.below,
    required this.details,
    required this.onAccept,
    required this.onDecline,
  });

  final String title;
  final Widget tag;
  final int fare;
  final String fareCaption;
  final Duration countdown;
  final bool running;
  final VoidCallback onTimeout;

  /// Line or chip under the ring ("Cash / UPI to you · 100% yours", "Paid by: Receiver").
  final Widget below;
  final List<Widget> details;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Scaffold(
      backgroundColor: RidoColors.surface,
      body: Column(
        children: [
          AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
            child: Material(
              color: RidoColors.coral600,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.m, RidoSpacing.gutter, RidoSpacing.xl),
                  child: Column(
                    children: [
                      Row(children: [
                        const Icon(Symbols.notifications_active_rounded, color: Colors.white, fill: 1, size: 26),
                        const SizedBox(width: RidoSpacing.s),
                        Expanded(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.h2.copyWith(color: Colors.white)),
                        ),
                        tag,
                      ]),
                      const SizedBox(height: RidoSpacing.m),
                      CountdownRing(
                        duration: countdown,
                        running: running,
                        onFinished: onTimeout,
                        trackColor: RidoColors.coral700,
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          FittedBox(child: Text(formatInr(fare), style: t.hero.copyWith(color: Colors.white))),
                          Text(fareCaption, style: t.bodySemibold.copyWith(color: Colors.white)),
                        ]),
                      ),
                      const SizedBox(height: RidoSpacing.l),
                      below,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.xl, RidoSpacing.gutter, RidoSpacing.l),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: details),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, 0, RidoSpacing.gutter, RidoSpacing.s),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                RidoButton(label: 'Accept', height: 64, onPressed: onAccept),
                const SizedBox(height: RidoSpacing.s),
                TextButton(
                  onPressed: onDecline,
                  style: TextButton.styleFrom(foregroundColor: RidoColors.navy700, minimumSize: const Size(160, 48)),
                  child: const Text('Decline'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// White pill on the coral header ("Bike", "3-wheeler").
class RequestVehicleTag extends StatelessWidget {
  const RequestVehicleTag({super.key, required this.vehicle, this.showIcon = true});
  final VehicleKind vehicle;
  final bool showIcon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: const BoxDecoration(color: RidoColors.surface, borderRadius: RidoRadii.pillRadius),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (showIcon) ...[
            Icon(vehicle.icon, color: RidoColors.coral600, size: 20, fill: 1),
            const SizedBox(width: 6),
          ],
          Text(vehicle.label, style: context.type.bodySemibold.copyWith(color: RidoColors.coral600)),
        ]),
      );
}

/// Pickup (green, "0.8 km away · 3 min") → drop ("4.2 km trip · ~14 min").
class RequestRoute extends StatelessWidget {
  const RequestRoute({super.key, required this.request, this.pickupTitle});
  final RideRequest request;

  /// Overrides the pickup title (e.g. "Peelamedu, Avinashi Road").
  final String? pickupTitle;

  @override
  Widget build(BuildContext context) => PickupDropConnector(
        pickupTitle: pickupTitle ?? request.pickup.name,
        pickupSubtitle: '${formatKm(request.pickupDistanceKm)} away · ${request.pickupEtaMin} min',
        pickupSubtitleColor: RidoColors.success,
        dropTitle: request.drop.name,
        dropSubtitle: '${formatKm(request.tripKm)} trip · ~${request.tripMin} min',
      );
}

/// Grey card with the passenger's initial, name and rating.
class RequestCustomerCard extends StatelessWidget {
  const RequestCustomerCard({super.key, required this.name, required this.rating});
  final String name;
  final double rating;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(RidoSpacing.l),
        decoration: const BoxDecoration(color: RidoColors.inputBg, borderRadius: RidoRadii.cardRadius),
        child: Row(children: [
          RidoAvatar(initials: name.substring(0, 1).toUpperCase(), size: 40),
          const SizedBox(width: RidoSpacing.l),
          Expanded(child: Text(name, style: context.type.h2, overflow: TextOverflow.ellipsis)),
          const Icon(Symbols.star_rounded, fill: 1, color: RidoColors.warning, size: 22),
          const SizedBox(width: RidoSpacing.xs),
          Text(rating.toStringAsFixed(1), style: RidoTextStyles.tabular(context.type.bodySemibold)),
        ]),
      );
}
