import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/passenger_session.dart';
import '../../state/ride_flow.dart';

/// Account › Safety preferences: "Prefer women driver", "Auto-share every trip", and a link
/// to emergency contacts.
class SafetyPreferencesScreen extends ConsumerWidget {
  const SafetyPreferencesScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final p = ref.watch(currentProfileProvider);
    final profile = ref.read(passengerProfileProvider.notifier);
    final contacts = p.emergencyContacts.map((c) => c.name).join(', ');

    return Scaffold(
      appBar: const RidoAppBar(
        title: 'Safety preferences',
        bottom: PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RidoListGroup(children: [
            _SwitchTile(
              icon: Symbols.woman_rounded,
              title: 'Prefer women driver',
              subtitle: "We'll match you with a woman driver when one is nearby.",
              value: p.preferWomenDriver,
              onChanged: (v) {
                profile.setPreferWomenDriver(v);
                ref.read(rideFlowProvider.notifier).setPreferWomenDriver(v);
              },
            ),
            _SwitchTile(
              icon: Symbols.share_location_rounded,
              title: 'Auto-share every trip',
              subtitle: 'Your emergency contacts get a live link when each ride starts.',
              value: p.autoShareTrips,
              onChanged: profile.setAutoShare,
            ),
          ]),
          const SizedBox(height: 16),
          RidoListGroup(children: [
            RidoListTile(
              icon: Symbols.contact_emergency_rounded,
              title: 'Emergency contacts',
              subtitle: contacts.isEmpty ? 'Add up to 3 people' : contacts,
              onTap: () => context.push(Routes.emergencyContacts),
            ),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(color: RidoColors.inputBg, borderRadius: RidoRadii.cardRadius),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Symbols.e911_emergency_rounded, color: RidoColors.sos, fill: 1),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'SOS is always one tap away during a ride. It calls 112 and alerts your contacts.',
                    style: t.bodySmall.copyWith(color: RidoColors.navy700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: RidoListTile(
          icon: icon,
          title: title,
          subtitle: subtitle,
          onTap: () => onChanged(!value),
          trailing: Switch(value: value, onChanged: onChanged),
        ),
      );
}
