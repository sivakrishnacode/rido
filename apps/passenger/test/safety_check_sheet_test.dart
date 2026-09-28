// The "Is everything OK?" / "Did you reach safely?" sheet: the answer goes to the API; "Get help" is returned so the
// app opens the SOS screen (also when the call failed).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_passenger/features/ride/safety_check_sheet.dart';
import 'package:rido_ui/rido_ui.dart';

import 'support/fake_safety.dart';
import 'support/harness.dart';

const _stop = SafetyCheck(tripId: 'trip1', kind: 'STOP', eventId: 'ev1', title: 'Is everything OK?', message: 'Your ride has been stopped for 5 min.');
const _arrival = SafetyCheck(tripId: 'trip1', kind: 'SAFE_ARRIVAL', eventId: 'ev2');

/// Opens the sheet for [check] from a button; the answer lands in [result].
Future<List<SafetyAnswer?>> _pump(WidgetTester tester, FakeSafety safety, SafetyCheck check) async {
  await loadTestFonts();
  usePhone(tester);
  final result = <SafetyAnswer?>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [liveSafetyProvider.overrideWithValue(safety)],
    child: MaterialApp(
      theme: RidoTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(onPressed: () async => result.add(await SafetyCheckSheet.show(context, check)), child: const Text('open')),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets("I'm OK answers the check and closes", (tester) async {
    final safety = FakeSafety();
    final result = await _pump(tester, safety, _stop);
    expect(find.text('Is everything OK?'), findsOneWidget);
    expect(find.text('Your ride has been stopped for 5 min.'), findsOneWidget);
    await tester.tap(find.text("I'm OK"));
    await tester.pumpAndSettle();
    expect(safety.answers, [(kind: 'STOP', eventId: 'ev1', ok: true)]);
    expect(result, [SafetyAnswer.ok]);
    expect(find.text('Is everything OK?'), findsNothing);
  });

  testWidgets('Get help raises the SOS and asks the app to open P-17, even offline', (tester) async {
    final safety = FakeSafety()..failAnswer = true;
    final result = await _pump(tester, safety, _stop);
    await tester.tap(find.text('Get help'));
    await tester.pumpAndSettle();
    expect(safety.answers.single.ok, isFalse);
    expect(result, [SafetyAnswer.help]);
  });

  testWidgets('after a night ride it asks "Did you reach safely?"', (tester) async {
    final safety = FakeSafety();
    final result = await _pump(tester, safety, _arrival);
    expect(find.text('Did you reach safely?'), findsOneWidget);
    await tester.tap(find.text('No, I need help'));
    await tester.pumpAndSettle();
    expect(safety.answers, [(kind: 'SAFE_ARRIVAL', eventId: 'ev2', ok: false)]);
    expect(result, [SafetyAnswer.help]);
  });

  test('checks parse from the socket event and the push data', () {
    final c = SafetyCheck.fromJson({'type': 'safety', 'kind': 'DEVIATION', 'tripId': 't9', 'eventId': 'e9', 'channel': 'safety'});
    expect((c.tripId, c.kind, c.eventId, c.isArrival), ('t9', 'DEVIATION', 'e9', false));
    expect(SafetyCheck.fromJson({'kind': 'SAFE_ARRIVAL', 'tripId': 't9'}).isArrival, isTrue);
  });
}
