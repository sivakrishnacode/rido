import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';

/// Live API: the trip's live-tracking link (`POST /trips/:id/share`), fetched once per trip; null when it couldn't
/// be made (offline, trip ended long ago) or in seed-data mode. The link itself stays valid until 30 min after the
/// trip ends, so it is kept for the trip.
final tripShareLinkProvider = FutureProvider.family<TripShareLink?, String>((ref, tripId) async {
  if (!ref.watch(isLiveApiProvider)) return null;
  try {
    return await ref.watch(liveSafetyProvider).shareLink(tripId);
  } catch (_) {
    return null;
  }
});

/// Trips whose share sheet was already offered automatically ("Auto-share trips"), so it opens once per trip.
class AutoSharePrompted extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// True the first time for [tripId] (and marks it), false after.
  bool claim(String tripId) {
    if (state.contains(tripId)) return false;
    state = {...state, tripId};
    return true;
  }
}

final autoSharePromptedProvider = NotifierProvider<AutoSharePrompted, Set<String>>(AutoSharePrompted.new);
