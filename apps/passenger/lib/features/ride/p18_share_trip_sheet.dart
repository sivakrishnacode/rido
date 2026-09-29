import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../common/launch.dart';
import '../../state/passenger_session.dart';
import '../../state/ride_flow.dart';
import '../../state/trip_safety.dart';
import 'widgets/trip_widgets.dart';

/// P-18 Share trip (sheet): live tracking link preview, WhatsApp / SMS / Copy link / More,
/// and the "until the ride ends" note.
class P18ShareTripSheet extends ConsumerWidget {
  const P18ShareTripSheet({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  /// Opens the share sheet over the current screen.
  static Future<void> show(BuildContext context) =>
      showTtSheet<void>(context, builder: (_) => const P18ShareTripSheet());

  /// Short live-tracking code for a trip ("K8Q2ZP" for the demo trip).
  static String codeFor(String tripId) {
    if (tripId == 'RD-DEMO') return 'K8Q2ZP';
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    var h = tripId.hashCode & 0x7fffffff;
    final b = StringBuffer();
    for (var i = 0; i < 6; i++) {
      b.write(alphabet[h % alphabet.length]);
      h ~/= alphabet.length;
      if (h == 0) h = 7919 * (i + 3);
    }
    return b.toString();
  }

  /// Opens another app with the trip text, then closes the sheet.
  void _open(BuildContext context, Future<void> launching) {
    if (showcase) return;
    final navigator = Navigator.of(context);
    launching.whenComplete(() => navigator.maybePop());
  }

  void _done(BuildContext context, String message) {
    showTtSnack(context, message);
    if (!showcase) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final ride = ref.watch(rideFlowProvider);
    final firstName = ref.watch(currentProfileProvider).firstName;
    final route = ride.routeOrDefault;
    final fix = showcase ? null : ref.read(rideFlowProvider.notifier).vehicle.value;
    final inTrip = ride.phase == RidePhase.inProgress;
    final vehiclePos = fix?.position ?? pointAlong(route, 0.62);
    final arrival = showcase ? DateTime(2026, 9, 24, 15, 42) : TtClock.now().add(Duration(minutes: ride.etaMin));
    final live = !showcase && ref.watch(isLiveApiProvider);
    // Live API: the trip's live-tracking page (signed link from the API). Until it has loaded, or if it couldn't be
    // made, share where the vehicle is now (a Google Maps link).
    final shareLink = live ? ref.watch(tripShareLinkProvider(ride.tripId)).value : null;
    final at = fix?.position ?? ride.pickup.location;
    final link = shareLink != null
        ? shareLink.url.replaceFirst(RegExp('^https?://'), '')
        : live
            ? 'maps.google.com/?q=${at.latitude.toStringAsFixed(5)},${at.longitude.toStringAsFixed(5)}'
            : 'tamiltaxi.co.in/t/${codeFor(ride.tripId)}';
    final linkUrl = shareLink?.url ?? 'https://$link';
    final status = showcase || inTrip
        ? 'arriving ${formatTime(arrival)}'
        : ride.phase == RidePhase.assigned
            ? 'driver ${ride.etaMin} min away'
            : 'live until the ride ends';

    final text = tripShareText(
      riderName: firstName,
      driver: ride.driver,
      vehicleLabel: ride.vehicle.label,
      drop: ride.drop,
      vehicleAt: live && shareLink == null ? at : null,
      status: live && shareLink == null ? null : 'Track live: $linkUrl',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Share your trip', style: t.h1)),
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Symbols.close_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: TtColors.surface,
            borderRadius: TtRadii.cardRadius,
            border: Border.all(color: TtColors.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 128,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: TtMap(
                          interactive: false,
                          showAttribution: false,
                          drop: ride.drop.location,
                          route: remainingPath(route, vehiclePos, fix?.progress ?? 0.62),
                          vehicles: [MapVehicle(position: vehiclePos, type: ride.vehicle.mapType, heading: fix?.heading ?? 250)],
                          fitPoints: [vehiclePos, ride.drop.location],
                          fitPadding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: const BoxDecoration(color: TtColors.sos, borderRadius: TtRadii.pillRadius),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text('LIVE', style: t.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$firstName's ride to ${ride.drop.name}", style: t.bodySemibold.copyWith(fontSize: 17)),
                    const SizedBox(height: 4),
                    Text(
                      '${ride.vehicle.label} · ${ride.driver.name} · ${ride.driver.plate} · $status',
                      style: t.bodySmall.copyWith(color: TtColors.navy700),
                    ),
                    const SizedBox(height: 8),
                    Text(link,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmallMedium.copyWith(color: TtColors.coral600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ShareOption(
              icon: Symbols.chat_rounded,
              label: 'WhatsApp',
              background: TtColors.successTint,
              foreground: TtColors.successText,
              onTap: () => _open(context, openWhatsApp(context, text)),
            ),
            _ShareOption(icon: Symbols.sms_rounded, label: 'SMS', onTap: () => _open(context, openSms(context, text))),
            _ShareOption(
              icon: Symbols.content_copy_rounded,
              label: 'Copy link',
              onTap: () {
                Clipboard.setData(ClipboardData(text: linkUrl));
                _done(context, 'Link copied');
              },
            ),
            _ShareOption(
              icon: Symbols.share_rounded,
              label: 'More',
              onTap: () => _open(context, shareText(context, text, subject: 'My Tamil Taxi trip')),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(color: TtColors.inputBg, borderRadius: TtRadii.cardRadius),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Symbols.visibility_rounded, color: TtColors.navy700),
              const SizedBox(width: 12),
              Expanded(
                child: Text('They can see your live location until the ride ends.',
                    style: t.body.copyWith(color: TtColors.navy700)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.background = TtColors.inputBg,
    this.foreground = TtColors.navy900,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Share via $label',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: TtRadii.cardRadius,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: background, shape: BoxShape.circle),
                  child: Icon(icon, color: foreground, fill: 1),
                ),
                const SizedBox(height: 8),
                Text(label, style: context.type.bodySmallMedium),
              ],
            ),
          ),
        ),
      );
}
