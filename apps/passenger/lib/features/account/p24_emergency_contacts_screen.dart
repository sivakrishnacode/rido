import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/phone.dart';
import '../../state/passenger_session.dart';
import 'p24b_add_contact_sheet.dart';

/// P-24 Emergency contacts: up to 3 people with a relation label, Add contact (P-24b sheet),
/// swipe or the menu to remove (with Undo), and "Auto-share every trip with these contacts".
class P24EmergencyContactsScreen extends ConsumerWidget {
  const P24EmergencyContactsScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  static const maxContacts = 3;

  Future<void> _remove(BuildContext context, WidgetRef ref, EmergencyContact c) async {
    final profile = ref.read(passengerProfileProvider.notifier);
    final removed = await profile.removeContact(c.id);
    if (!context.mounted || !removed) return;
    showRidoSnack(context, '${c.name} removed', actionLabel: 'Undo', onAction: () => profile.addContact(c));
  }

  Future<void> _add(BuildContext context) async {
    final added = await P24bAddContactSheet.show(context);
    if (added != null && context.mounted) showRidoSnack(context, '${added.name} added', success: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final p = ref.watch(currentProfileProvider);
    final contacts = p.emergencyContacts;
    final left = maxContacts - contacts.length;

    return Scaffold(
      appBar: const RidoAppBar(
        title: 'Emergency contacts',
        bottom: PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("We'll send them your live location if you press SOS. Add up to 3 people.",
              style: t.body.copyWith(color: RidoColors.navy700)),
          const SizedBox(height: 16),
          if (contacts.isEmpty)
            RidoCard(
              child: Row(children: [
                const Icon(Symbols.group_add_rounded, color: RidoColors.navy500),
                const SizedBox(width: 12),
                Expanded(child: Text('No contacts yet. Add someone you trust.', style: t.bodySmall)),
              ]),
            )
          else
            RidoListGroup(children: [
              for (final c in contacts)
                Dismissible(
                  key: ValueKey(c.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: RidoColors.errorTint,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Symbols.delete_rounded, color: RidoColors.error),
                  ),
                  onDismissed: (_) => _remove(context, ref, c),
                  child: _ContactTile(
                    contact: c,
                    onCall: () => showRidoSnack(context, 'Calling ${c.name}'),
                    onRemove: () => _remove(context, ref, c),
                  ),
                ),
            ]),
          const SizedBox(height: 16),
          RidoButton.secondary(
            label: 'Add contact',
            icon: Symbols.person_add_rounded,
            onPressed: left > 0 ? () => _add(context) : null,
          ),
          const SizedBox(height: 8),
          Text(
            left > 0
                ? 'You can add $left more'
                : "You've added 3 contacts. Remove one to add someone else.",
            style: t.bodySmall.copyWith(color: RidoColors.navy500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          MergeSemantics(
            child: RidoCard(
              onTap: () => ref.read(passengerProfileProvider.notifier).setAutoShare(!p.autoShareTrips),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Auto-share every trip with these contacts', style: t.bodySemibold.copyWith(fontSize: 17)),
                        const SizedBox(height: 2),
                        Text('They get a live link when each ride starts.',
                            style: t.bodySmall.copyWith(color: RidoColors.navy500)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: p.autoShareTrips,
                    onChanged: (v) => ref.read(passengerProfileProvider.notifier).setAutoShare(v),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onCall, required this.onRemove});
  final EmergencyContact contact;
  final VoidCallback onCall;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      child: Row(
        children: [
          RidoAvatar(initials: contact.name.substring(0, 1).toUpperCase(), size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(contact.name, style: t.bodySemibold.copyWith(fontSize: 17)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: const BoxDecoration(color: RidoColors.inputBg, borderRadius: RidoRadii.pillRadius),
                      child: Text(contact.relation, style: t.caption.copyWith(color: RidoColors.navy700)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(displayPhone(contact.phone), style: RidoTextStyles.tabular(t.body.copyWith(color: RidoColors.navy500))),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Options for ${contact.name}',
            icon: const Icon(Symbols.more_vert_rounded, color: RidoColors.navy500),
            onSelected: (v) => v == 'call' ? onCall() : onRemove(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'call', child: Text('Call')),
              PopupMenuItem(value: 'remove', child: Text('Remove')),
            ],
          ),
        ],
      ),
    );
  }
}
