import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../state/driver_account.dart';
import '../../state/driver_session.dart';
import 'widgets/job_common.dart';

/// D-18b Driver SOS: "Emergency help", Call 112 (confirm → "Calling 112"), the emergency
/// contact gets "Live location sent ✓", the safety team is notified, and the shared trip
/// details are listed. "I'm safe" goes back.
class D18bDriverSosScreen extends ConsumerStatefulWidget {
  const D18bDriverSosScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D18bDriverSosScreen> createState() => _D18bDriverSosScreenState();
}

class _D18bDriverSosScreenState extends ConsumerState<D18bDriverSosScreen> {
  EmergencyContact? _contact;
  late bool _sent = widget.showcase;
  late bool _teamNotified = widget.showcase;
  Timer? _timer;
  Timer? _teamTimer;

  @override
  void initState() {
    super.initState();
    ref.read(driverRepositoryProvider).emergencyContact().then((c) {
      if (!mounted) return;
      setState(() => _contact = c);
      if (!widget.showcase) {
        final stagger = ref.read(simTimingProvider)(SimTimings.sosContactStagger);
        _timer = Timer(stagger, () {
          if (mounted) setState(() => _sent = true);
        });
        _teamTimer = Timer(stagger * 2, () {
          if (mounted) setState(() => _teamNotified = true);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _teamTimer?.cancel();
    super.dispose();
  }

  Future<void> _call112() async {
    final ok = await showRidoConfirm(
      context,
      title: 'Call 112?',
      message: 'This connects you to the national emergency number.',
      confirmLabel: 'Call 112',
      cancelLabel: 'Not now',
      destructive: true,
      icon: Symbols.call_rounded,
    );
    if (ok && mounted) showRidoSnack(context, 'Calling 112');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final job = ref.watch(driverSessionProvider.select((s) => s.job)) ?? Seed.rideRequest;
    final profile = ref.watch(driverProfileProvider).value ?? Seed.karthik;
    final contact = _contact;

    Widget detail(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Text(label, style: t.body.copyWith(color: RidoColors.navy700)),
            const SizedBox(width: RidoSpacing.l),
            Expanded(
              child: Text(value,
                  textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySemibold),
            ),
          ]),
        );

    return Scaffold(
      backgroundColor: RidoColors.surface,
      body: Column(
        children: [
          AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
            child: Material(
              color: RidoColors.sos,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(RidoSpacing.xs, 0, RidoSpacing.gutter, RidoSpacing.xl),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => popOrHome(context),
                      icon: const Icon(Symbols.close_rounded, color: Colors.white),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: RidoSpacing.m),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Emergency help', style: t.display.copyWith(color: Colors.white)),
                        const SizedBox(height: RidoSpacing.xs),
                        Text('Stay calm, ${profile.firstName}. Help is one tap away.',
                            style: t.body.copyWith(color: Colors.white)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.xl, RidoSpacing.gutter, RidoSpacing.l),
              children: [
                SizedBox(
                  height: 64,
                  child: FilledButton.icon(
                    onPressed: _call112,
                    style: FilledButton.styleFrom(
                      backgroundColor: RidoColors.sos,
                      foregroundColor: Colors.white,
                      textStyle: t.h1,
                    ),
                    icon: const Icon(Symbols.call_rounded, fill: 1, size: 28),
                    label: const Text('Call 112'),
                  ),
                ),
                const SectionLabel('Alert my emergency contact'),
                Row(children: [
                  RidoAvatar(initials: contact == null ? '…' : initialsOf(contact.name).substring(0, 1), tone: AvatarTone.navy, size: 44),
                  const SizedBox(width: RidoSpacing.m),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(contact == null ? 'Loading…' : '${contact.name.split(' ').first} (${contact.relation})',
                          style: t.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Semantics(
                        liveRegion: true,
                        child: _sent
                            ? Row(children: [
                                const Icon(Symbols.check_circle_rounded, color: RidoColors.success, fill: 1, size: 18),
                                const SizedBox(width: 6),
                                Text('Live location sent', style: t.bodySmallMedium.copyWith(color: RidoColors.successText)),
                              ])
                            : Text('Sending live location…', style: t.bodySmall.copyWith(color: RidoColors.navy500)),
                      ),
                    ]),
                  ),
                  RoundIconButton(
                    icon: Symbols.call_rounded,
                    tooltip: 'Call ${contact?.name ?? 'emergency contact'}',
                    background: RidoColors.inputBg,
                    foreground: RidoColors.navy900,
                    size: 48,
                    onPressed: () => showRidoSnack(context, 'Calling ${contact?.name ?? 'your emergency contact'}'),
                  ),
                ]),
                const SizedBox(height: RidoSpacing.xl),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _teamNotified
                      ? const RidoBanner(
                          key: ValueKey('notified'),
                          type: RidoBannerType.success,
                          icon: Symbols.verified_user_rounded,
                          title: 'Rido safety team has been notified',
                          message: "They'll call you within 2 minutes.",
                        )
                      : const RidoBanner(
                          key: ValueKey('notifying'),
                          type: RidoBannerType.info,
                          icon: Symbols.shield_rounded,
                          title: 'Notifying Rido safety team…',
                        ),
                ),
                const SizedBox(height: RidoSpacing.l),
                RidoCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('TRIP DETAILS SHARED', style: t.overline),
                    const SizedBox(height: RidoSpacing.s),
                    detail(job.isDelivery ? 'Receiver' : 'Passenger',
                        '${job.customerName} · ${job.customerRating.toStringAsFixed(1)}★'),
                    detail('Trip', '${job.pickup.name.split(' ').first} → ${job.drop.name.split(' ').first}'),
                    detail('Your vehicle', profile.plate),
                    detail('Now at', job.drop.id == Seed.brookefields.id ? 'DB Road, RS Puram' : job.drop.address),
                  ]),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.s, RidoSpacing.gutter, RidoSpacing.l),
              child: RidoButton.secondary(label: "I'm safe", onPressed: () => popOrHome(context)),
            ),
          ),
        ],
      ),
    );
  }
}
