import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' show Distance;
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/passenger_session.dart';
import '../../state/ride_flow.dart';

/// P-17 SOS · Emergency help (full-screen modal): Call 112, live location sent to each
/// emergency contact one by one, safety team notified, the trip details shared, and "I'm safe".
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

  @override
  void initState() {
    super.initState();
    if (widget.showcase) {
      _sent = _maxContacts;
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
    if (ok && mounted) showRidoSnack(context, 'Calling 112');
  }

  /// Nearest named place to the vehicle, for "Now at".
  String _nowAt(RideFlowState ride) {
    if (widget.showcase) return 'DB Road, RS Puram';
    final pos = ref.read(rideFlowProvider.notifier).vehicle.value?.position;
    if (pos == null || !ride.isActive) return ride.pickup.name;
    const d = Distance();
    final nearest = Seed.places.reduce((a, b) => d(a.location, pos) <= d(b.location, pos) ? a : b);
    return nearest.address;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final ride = ref.watch(rideFlowProvider);
    final contacts = ref.watch(passengerProfileProvider).value?.emergencyContacts ?? Seed.priya.emergencyContacts;
    final showTrip = widget.showcase || ride.isActive;
    final driver = ride.driver;

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
                else
                  for (var i = 0; i < contacts.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _ContactRow(contact: contacts[i], sent: i < _sent),
                  ],
                const SizedBox(height: 20),
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
  const _ContactRow({required this.contact, required this.sent});
  final EmergencyContact contact;
  final bool sent;

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
                onTap: () => showRidoSnack(context, 'Calling ${contact.name}'),
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
