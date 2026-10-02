// Live place search: nothing is asked under 4 letters (recents stay with a hint), one request after a pause, and a
// failed search shows Retry rather than loading rows.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_passenger/router/routes.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import 'support/harness.dart';

/// Answers like [ApiPlacesRepository] (nothing under 4 letters) and records every query it gets.
class _LivePlaces extends MockPlacesRepository {
  _LivePlaces(super.db, super.settings, this.asked, {this.fail = false});
  final List<String> asked;
  final bool fail;

  @override
  Future<List<Place>> search(String query, {LatLng? origin, bool anywhere = false}) async {
    asked.add(query);
    final q = query.trim();
    if (q.isEmpty) return anywhere ? const [] : Seed.recentDestinations;
    if (q.length < kMinPlaceQuery) return const [];
    if (fail) throw const OfflineException();
    return super.search(query, origin: origin, anywhere: anywhere);
  }
}

Future<List<Override>> _live(WidgetTester tester, List<String> asked, {bool fail = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await tester.runAsync(SharedPreferences.getInstance);
  final api = ApiClient(baseUrl: 'http://localhost:0/v1', session: ApiSession(prefs!));
  return [
    isLiveApiProvider.overrideWithValue(true),
    apiClientProvider.overrideWithValue(api),
    placesRepositoryProvider.overrideWith(
      (ref) => _LivePlaces(ref.watch(mockDatabaseProvider), () => ref.read(demoSettingsProvider), asked, fail: fail),
    ),
  ];
}

void main() {
  testWidgets('P-08: under 4 letters the recents stay with a hint; the search starts at 4, after a pause', (tester) async {
    final asked = <String>[];
    await pumpRoute(tester, Routes.search, overrides: await _live(tester, asked));
    expect(asked, ['']);

    final drop = find.byType(TextField).last;
    for (final text in ['B', 'Br', 'Bro']) {
      await tester.enterText(drop, text);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(asked, [''], reason: 'nothing searched below 4 letters; the recents were kept');
    expect(find.text('Type at least 4 letters to search'), findsOneWidget);
    expect(find.text(Seed.recentDestinations.first.name), findsOneWidget);

    await tester.enterText(drop, 'Broo');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(drop, 'Brook');
    await tester.pump(const Duration(milliseconds: 400));
    expect(asked, ['', 'Brook'], reason: 'one request once typing pauses');
    expect(find.text('Type at least 4 letters to search'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('place sheet (parcel, saved places): short text lists the recents with the hint', (tester) async {
    final asked = <String>[];
    await pumpRoute(tester, Routes.savedPlaceEditor(), overrides: await _live(tester, asked));
    await tester.tap(find.text('Choose'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField).last, 'Gan');
    await tester.pump(const Duration(milliseconds: 600));
    expect(asked, ['']);
    expect(find.text('Type at least 4 letters to search'), findsOneWidget);
    expect(find.text(Seed.recentDestinations.first.name), findsOneWidget);
  });

  testWidgets('P-35b: a failed search shows why and Retry, no loading rows under it', (tester) async {
    final asked = <String>[];
    await pumpRoute(tester, Routes.outstationSearch, overrides: await _live(tester, asked, fail: true));
    await tester.enterText(find.byType(TextField).last, 'Oo');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Type at least 4 letters to search'), findsOneWidget);
    expect(asked, isEmpty);

    await tester.enterText(find.byType(TextField).last, 'Ooty');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(asked, ['Ooty']);
    expect(find.textContaining("You're offline"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(SkeletonBox), findsNothing);
  });
}
