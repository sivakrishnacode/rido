import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/phone.dart';
import '../../common/flags.dart';
import '../../router/routes.dart';
import '../../state/session_actions.dart';
import '../../state/passenger_session.dart';

/// P-23 Account: profile header with Edit, saved places, emergency contacts, safety
/// preferences, help, terms, about, the Design gallery (prototype builds) and Log out.
class P23AccountScreen extends ConsumerWidget {
  const P23AccountScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  static const version = '0.1.0';

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showRidoConfirm(
      context,
      title: 'Log out?',
      message: 'You can log in again with your phone number.',
      icon: Symbols.logout_rounded,
      confirmLabel: 'Log out',
      cancelLabel: 'Cancel',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await signOut(ref);
    if (context.mounted) context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final p = ref.watch(currentProfileProvider);
    String onOff(bool v) => v ? 'On' : 'Off';
    final places = p.savedPlaces.map((s) => s.label).join(', ');
    final contacts = p.emergencyContacts.map((c) => c.name).join(', ');

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Material(
            color: RidoColors.surface,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 8, 20),
                child: Row(
                  children: [
                    RidoAvatar(initials: p.initials, size: 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: t.h1, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(displayPhone(p.phone), style: RidoTextStyles.tabular(t.body.copyWith(color: RidoColors.navy700))),
                        ],
                      ),
                    ),
                    TextButton(onPressed: () => context.push(Routes.editProfile), child: const Text('Edit')),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RidoListGroup(children: [
                  RidoListTile(
                    icon: Symbols.bookmark_rounded,
                    title: 'Saved places',
                    subtitle: places.isEmpty ? 'Add Home or Work' : places,
                    onTap: () => context.push(Routes.savedPlaces),
                  ),
                  RidoListTile(
                    icon: Symbols.contact_emergency_rounded,
                    title: 'Emergency contacts',
                    subtitle: contacts.isEmpty ? 'Add up to 3 people' : contacts,
                    onTap: () => context.push(Routes.emergencyContacts),
                  ),
                  RidoListTile(
                    icon: Symbols.shield_person_rounded,
                    title: 'Safety preferences',
                    subtitle: 'Women driver: ${onOff(p.preferWomenDriver)} · Auto-share trips: ${onOff(p.autoShareTrips)}',
                    onTap: () => context.push(Routes.safety),
                  ),
                ]),
                const SizedBox(height: 16),
                RidoListGroup(children: [
                  RidoListTile(
                    icon: Symbols.volunteer_activism_rounded,
                    title: 'Contribute',
                    subtitle: 'Rido is free. Help keep it running',
                    onTap: () => context.push(Routes.contribute),
                  ),
                ]),
                const SizedBox(height: 16),
                RidoListGroup(children: [
                  RidoListTile(
                    icon: Symbols.support_agent_rounded,
                    title: 'Help & support',
                    onTap: () => context.push(Routes.help()),
                  ),
                  RidoListTile(
                    icon: Symbols.policy_rounded,
                    title: 'Terms & privacy',
                    onTap: () => context.push(Routes.legal('terms')),
                  ),
                  RidoListTile(
                    icon: Symbols.info_rounded,
                    title: 'About Rido',
                    onTap: () => context.push(Routes.about),
                  ),
                  if (kShowDesignGallery)
                    RidoListTile(
                      icon: Symbols.palette_rounded,
                      title: 'Design gallery',
                      subtitle: 'Every screen and the demo controls',
                      onTap: () => context.push(Routes.gallery),
                    ),
                ]),
                const SizedBox(height: 16),
                RidoListGroup(children: [
                  RidoListTile(
                    icon: Symbols.logout_rounded,
                    title: 'Log out',
                    destructive: true,
                    onTap: () => _logout(context, ref),
                  ),
                ]),
                const SizedBox(height: 16),
                Text(
                  'Rido $version · Made in Coimbatore',
                  style: t.bodySmall.copyWith(color: RidoColors.navy500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
