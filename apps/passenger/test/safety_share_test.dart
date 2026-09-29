// Live trip share link (P-18 / P-16): the sheet shares the API's tracking link (maps link if it couldn't be made),
// and "Auto-share trips" opens the sheet once when the ride starts.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_passenger/features/ride/p16_ride_in_progress_screen.dart';
import 'package:tamiltaxi_passenger/features/ride/p18_share_trip_sheet.dart';
import 'package:tamiltaxi_passenger/state/ride_flow.dart';
import 'package:tamiltaxi_passenger/state/trip_safety.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import 'support/fake_safety.dart';
import 'support/harness.dart';

const _url = 'https://admin.tamiltaxi.test/track/trip1.abc.SIGNATURE';

/// A ride in progress (no simulator, no network).
class FixedRide extends RideFlowController {
  FixedRide(this.initial);
  final RideFlowState initial;
  @override
  RideFlowState build() => initial;
}

final _ride = RideFlowState(phase: RidePhase.inProgress, tripId: 'trip1', route: [Seed.gandhipuram.location, Seed.brookefields.location]);

List<Override> _live(FakeSafety safety) => [
      isLiveApiProvider.overrideWithValue(true),
      liveSafetyProvider.overrideWithValue(safety),
      rideFlowProvider.overrideWith(() => FixedRide(_ride)),
    ];

Future<void> _pump(WidgetTester tester, Widget home, List<Override> overrides) async {
  await loadTestFonts();
  usePhone(tester);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(theme: TtTheme.light(), home: home),
  ));
  await tester.pump();
  // Mock profile latency and the share-link future.
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

void main() {
  String? copied;
  setUp(() {
    copied = null;
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
  });

  testWidgets('P-18 shares the live tracking link from the API', (tester) async {
    final safety = FakeSafety();
    await _pump(tester, const Scaffold(body: SingleChildScrollView(child: P18ShareTripSheet())), _live(safety));
    expect(safety.shareCalls, 1);
    expect(find.text('admin.tamiltaxi.test/track/trip1.abc.SIGNATURE'), findsOneWidget);

    await tester.tap(find.text('Copy link'));
    await tester.pump();
    expect(copied, _url);
  });

  testWidgets('P-18 falls back to a maps link when the link could not be made', (tester) async {
    await _pump(tester, const Scaffold(body: SingleChildScrollView(child: P18ShareTripSheet())), _live(FakeSafety(failShare: true)));
    expect(find.textContaining('maps.google.com/?q='), findsOneWidget);
  });

  testWidgets('Auto-share opens the share sheet once when the ride is in progress', (tester) async {
    final safety = FakeSafety();
    await _pump(tester, const P16RideInProgressScreen(), _live(safety));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Share your trip'), findsOneWidget);
  });

  test('the automatic share prompt is claimed once per trip', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final prompted = c.read(autoSharePromptedProvider.notifier);
    expect(prompted.claim('trip1'), isTrue);
    expect(prompted.claim('trip1'), isFalse);
    expect(prompted.claim('trip2'), isTrue);
  });
}
