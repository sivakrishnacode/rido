import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/passenger_session.dart';

/// Icon for a saved place label.
IconData savedPlaceIcon(SavedPlaceKind kind) => switch (kind) {
      SavedPlaceKind.home => Symbols.home_rounded,
      SavedPlaceKind.work => Symbols.work_rounded,
      SavedPlaceKind.other => Symbols.bookmark_rounded,
    };

/// Account › Saved places: the passenger's Home, Work and other places; tap to edit, or add one.
class SavedPlacesScreen extends ConsumerWidget {
  const SavedPlacesScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final places = ref.watch(currentProfileProvider).savedPlaces;
    return Scaffold(
      appBar: const RidoAppBar(
        title: 'Saved places',
        bottom: PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Book faster: tap a saved place on Home to set it as your drop.',
              style: t.body.copyWith(color: RidoColors.navy700)),
          const SizedBox(height: 16),
          if (places.isEmpty)
            RidoCard(
              child: Text('No saved places yet. Add Home or Work to book in one tap.', style: t.bodySmall),
            )
          else
            RidoListGroup(children: [
              for (final p in places)
                RidoListTile(
                  icon: savedPlaceIcon(p.kind),
                  title: p.label,
                  subtitle: p.place.fullAddress,
                  onTap: () => context.push(Routes.savedPlaceEditor(p.id)),
                ),
            ]),
          const SizedBox(height: 16),
          RidoButton.secondary(
            label: 'Add a place',
            icon: Symbols.add_location_alt_rounded,
            onPressed: () => context.push(Routes.savedPlaceEditor()),
          ),
        ],
      ),
    );
  }
}
