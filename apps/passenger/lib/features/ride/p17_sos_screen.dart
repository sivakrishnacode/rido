import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' show Distance;
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/launch.dart';
import '../../common/phone.dart';
import '../../router/routes.dart';
import '../../state/passenger_session.dart';
import '../../state/ride_flow.dart';
import '../../state/trip_safety.dart';

/// P-17 SOS · Emergency help (full-screen modal): Call 112, live location sent to each
/// emergency contact one by one, safety team notified, the trip details shared, and "I'm safe".
///
/// Live API, during a trip: opening it raises the SOS on the server first (`POST /trips/:id/sos`: admins are
/// alerted, the answer carries a live tracking link). If that fails (offline), the phone's own apps still work:
/// Call 112 and "Text my location" (the SMS carries the live link when there is one, else a maps link).
class P17SosScreen extends ConsumerStatefulWidget {
  const P17SosScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P17SosScreen> createState() => _P17SosScreenState();
}

class _P17SosScreenState extends ConsumerState<P17SosScreen> {
  static const _maxContacts = 3;
  int _sent = 0;
  Timer? _timer;

  /// Live API: the server SOS (null until it answered), whether it is being sent, and whether it failed.
  SosAlert? _alert;
  bool _alerting = false;
  bool _alertFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.showcase) {
      _sent = _maxContacts;
      return;
    }
    // Live API: the SOS goes to the server at once; the passenger texts contacts from their own phone.
    if (ref.read(isLiveApiProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _raiseSos());
      return;
    }
    final stagger = ref.read(simTimingProvider)(SimTimings.sosContactStagger);
    _timer = Timer.periodic(stagger, (t) {
      if (!mounted) return;
      setState(() => _sent++);
      if (_sent >= _maxContacts) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Live API: records the SOS for the active trip (admins get a push). No trip → nothing to raise it on.
  Future<void> _raiseSos() async {
    final ride = ref.read(rideFlowProvider);
    if (!mounted || !ride.isActive || _alerting) return;
    setState(() {
      _alerting = true;
      _alertFailed = false;
    });
    try {
      final at = ref.read(rideFlowProvider.notifier).vehicle.value?.position;
      final alert = await ref.read(liveSafetyProvider).sos(ride.tripId, at: at);
      if (mounted) setState(() => _alert = alert);
    } catch (_) {
      if (mounted) setState(() => _alertFailed = true);
    } finally {
      if (mounted) setState(() => _alerting = false);
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.ride);
    }
  }

  Future<void> _call112() async {
    final ok = await showRidoConfirm(
      context,
      title: 'Call 112?',
      message: 'This connects you to the national emergency number.',
      icon: Symbols.call_rounded,
      confirmLabel: 'Call 112',
      cancelLabel: 'Cancel',
      destructive: true,
    );
    if (ok && mounted) await callNumber(context, '112');
  }

  /// Live API: opens the SMS app to [contacts] with the trip details and a map link to the vehicle.
  Future<void> _textContacts(List<EmergencyContact> contacts, RideFlowState ride) async {
    final pos = ref.read(rideFlowProvider.notifier).vehicle.value?.position ?? ride.pickup.location;
    final me = ref.read(currentProfileProvider).firstName;
    final body = sosSmsBody(
      me: me,
      ride: ride,
      at: pos,
      liveUrl: _alert?.shareUrl ?? (ride.isActive ? ref.read(tripShareLinkProvider(ride.tripId)).value?.url : null),
    );
    await openSms(context, body, to: contacts.map((c) => apiPhone(c.phone)).join(','));
  }

  /// Nearest named place to the vehicle, for "Now at".
  String _nowAt(RideFlowState ride) {
    if (widget.showcase) return 'DB Road, RS Puram';
    final pos = ref.read(rideFlowProvider.notifier).vehicle.value?.position;
    if (pos == null || !ride.isActive) return ride.pickup.name;
    // Live API: coordinates, not the nearest demo landmark (which may be kilometres away).
    if (ref.read(isLiveApiProvider)) return '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
    const d = Distance();
    final nearest = Seed.places.reduce((a, b) => d(a.location, pos) <= d(b.location, pos) ? a : b);
    return nearest.address;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final ride = ref.watch(rideFlowProvider);
    final contacts = ref.watch(currentProfileProvider).emergencyContacts;
    final showTrip = widget.showcase || ride.isActive;
    final driver = ride.driver;
    final live = !widget.showcase && ref.watch(isLiveApiProvider);

    return Scaffold(
      backgroundColor: RidoColors.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: RidoColors.sos,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _close,
                      icon: const Icon(Symbols.close_rounded, color: Colors.white),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Emergency help', style: t.display.copyWith(color: Colors.white, fontSize: 30)),
                          const SizedBox(height: 4),
                          Text('Stay calm. Help is one tap away.', style: t.body.copyWith(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              children: [
                Semantics(
                  button: true,
                  label: 'Call 112',
                  excludeSemantics: true,
                  child: Material(
                    color: RidoColors.sos,
                    shape: const StadiumBorder(),
                    elevation: 3,
                    shadowColor: RidoColors.sos.withValues(alpha: 0.4),
                    child: InkWell(
                      key: const ValueKey('call-112'),
                      customBorder: const StadiumBorder(),
                      onTap: _call112,
                      child: SizedBox(
                        height: 64,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Symbols.call_rounded, fill: 1, color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            Text('Call 112', style: t.h1.copyWith(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SectionLabel('Alert my emergency contacts'),
                if (contacts.isEmpty)
                  RidoCard(
                    onTap: () => context.push(Routes.emergencyContacts),
                    child: Row(children: [
                      const Icon(Symbols.person_add_rounded, color: RidoColors.coral600),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Add an emergency contact', style: t.bodyMedium)),
                      const Icon(Symbols.chevron_right_rounded, color: RidoColors.navy500),
                    ]),
                  )
                else ...[
                  for (var i = 0; i < contacts.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _ContactRow(contact: contacts[i], sent: i < _sent, manual: live),
                  ],
                  if (live) ...[
                    const SizedBox(height: 8),
                    RidoButton.secondary(
                      label: 'Text my location to ${contacts.length == 1 ? contacts.first.name.split(' ').first : 'all'}',
                      icon: Symbols.sms_rounded,
                      onPressed: () => _textContacts(contacts, ride),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                if (live && ride.isActive) ...[
                  _SafetyTeamBanner(alerting: _alerting, alerted: _alert != null, failed: _alertFailed, onRetry: _raiseSos),
                  const SizedBox(height: 12),
                ],
                if (live)
                  RidoCard(
                    onTap: () => context.push(Routes.newTicket(topic: 'Safety concern', tripId: ride.isActive ? ride.tripId : null)),
                    child: Row(children: [
                      const Icon(Symbols.support_agent_rounded, color: RidoColors.coral600),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Report this to the Rido safety team', style: t.bodyMedium)),
                      const Icon(Symbols.chevron_right_rounded, color: RidoColors.navy500),
                    ]),
                  )
                else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: RidoColors.successTint,
                    borderRadius: RidoRadii.cardRadius,
                    border: Border.all(color: RidoColors.success),
                  ),
                  child: Row(
                    children: [
                      const Icon(Symbols.verified_user_rounded, fill: 1, color: RidoColors.successText, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Rido safety team has been notified', style: t.bodySemibold),
                            Text("They'll call you within 2 minutes.", style: t.bodySmall.copyWith(color: RidoColors.navy700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                RidoCard(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionLabel('Trip details shared', padding: EdgeInsets.fromLTRB(0, 12, 0, 8)),
                      if (showTrip) ...[
                        _InfoRow(label: 'Driver', value: '${driver.name} · ${driver.vehicleModel}'),
                        _InfoRow(label: 'Plate', value: driver.plate),
                      ],
                      _InfoRow(label: 'Now at', value: _nowAt(ride)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: RidoButton.secondary(label: "I'm safe", onPressed: _close),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, required this.sent, this.manual = false});
  final EmergencyContact contact;
  final bool sent;

  /// Live API: no automatic alert; shows the relation and phone instead of a sending state.
  final bool manual;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          RidoAvatar(initials: contact.name.substring(0, 1).toUpperCase(), size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name, style: t.bodySemibold.copyWith(fontSize: 17)),
                if (manual)
                  Text('${contact.relation} · ${displayPhone(contact.phone)}', style: t.bodySmall.copyWith(color: RidoColors.navy500))
                else
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: sent
                      ? Row(
                          key: const ValueKey('sent'),
                          children: [
                            const Icon(Symbols.check_circle_rounded, fill: 1, size: 16, color: RidoColors.successText),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text('Live location sent',
                                  style: t.bodySmallMedium.copyWith(color: RidoColors.successText)),
                            ),
                          ],
                        )
                      : Row(
                          key: const ValueKey('sending'),
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text('Sending live location…',
                                  style: t.bodySmall.copyWith(color: RidoColors.navy500)),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Call ${contact.name}',
            child: Material(
              color: RidoColors.inputBg,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => callNumber(context, contact.phone, name: contact.name),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Symbols.call_rounded, color: RidoColors.navy900, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.body.copyWith(color: RidoColors.navy700)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(value, style: t.bodySemibold, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

/// The SMS to emergency contacts: who, the live tracking link (else a maps link to [at]) and the trip details.
String sosSmsBody({required String me, required RideFlowState ride, required LatLng at, String? liveUrl}) {
  final where = 'https://maps.google.com/?q=${at.latitude.toStringAsFixed(5)},${at.longitude.toStringAsFixed(5)}';
  if (!ride.isActive) return 'SOS from $me. I need help. My location: $where';
  final trip = tripShareText(
    riderName: me,
    driver: ride.driver,
    vehicleLabel: ride.vehicle.label,
    drop: ride.drop,
    vehicleAt: liveUrl == null ? at : null,
    status: liveUrl == null ? null : 'Track live: $liveUrl',
  );
  return 'SOS from $me. I need help.\n$trip';
}

/// Live API: whether the Rido safety team got the SOS (sending / alerted / failed with Try again).
class _SafetyTeamBanner extends StatelessWidget {
  const _SafetyTeamBanner({required this.alerting, required this.alerted, required this.failed, required this.onRetry});
  final bool alerting;
  final bool alerted;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final (Color bg, Color fg, IconData icon, String title, String body) = alerted
        ? (RidoColors.successTint, RidoColors.successText, Symbols.verified_user_rounded, 'Rido safety team has been alerted',
            'They can see your trip and location. Call 112 if you are in danger.')
        : failed
            ? (RidoColors.sos.withValues(alpha: 0.08), RidoColors.sos, Symbols.wifi_off_rounded, "Couldn't reach Rido",
                'Call 112 and text your contacts below.')
            : (RidoColors.inputBg, RidoColors.navy700, Symbols.shield_rounded, 'Alerting Rido safety team…', 'Sending your trip and location.');
    return Semantics(
      liveRegion: true,
      child: Container(
        key: ValueKey(alerted ? 'sos-alerted' : failed ? 'sos-failed' : 'sos-alerting'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bg, borderRadius: RidoRadii.cardRadius, border: Border.all(color: fg.withValues(alpha: 0.5))),
        child: Row(children: [
          if (alerting && !alerted)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
          else
            Icon(icon, fill: 1, color: fg, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.bodySemibold),
              Text(body, style: t.bodySmall.copyWith(color: RidoColors.navy700)),
            ]),
          ),
          if (failed && !alerting) TextButton(onPressed: onRetry, child: const Text('Try again')),
        ]),
      ),
    );
  }
}
