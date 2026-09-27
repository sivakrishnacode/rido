// P-10 Butterfly (women riders): Any driver / Preferred / Women only, each explained in one line.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_passenger/features/ride/p10_choose_vehicle_screen.dart';
import 'package:rido_passenger/features/ride/p10b_who_is_riding_sheet.dart';
import 'package:rido_ui/rido_ui.dart';

import 'support/harness.dart';

const _out = String.fromEnvironment('OUT');
const _outRider = String.fromEnvironment('OUT_RIDER');

void main() {
  testWidgets('Butterfly switches between any driver, preferred and women only', (tester) async {
    await loadTestFonts();
    usePhone(tester, height: 400);
    var value = WomenDriverPref.none;
    await tester.pumpWidget(MaterialApp(
      theme: RidoTheme.light(),
      home: Scaffold(
        body: RepaintBoundary(
          key: shotKey,
          child: StatefulBuilder(
            builder: (context, setState) => Padding(
              padding: const EdgeInsets.all(16),
              child: ButterflyCard(value: value, onChanged: (v) => setState(() => value = v)),
            ),
          ),
        ),
      ),
    ));
    expect(find.text('Butterfly'), findsWidgets);
    expect(find.textContaining('Only women drivers'), findsNothing);

    await tester.tap(find.text('Women only'));
    await tester.pumpAndSettle();
    expect(value, WomenDriverPref.only);
    expect(find.text('Only women drivers get your request. It can take a little longer to find one.'), findsOneWidget);

    await tester.tap(find.text('Preferred'));
    await tester.pumpAndSettle();
    expect(value, WomenDriverPref.preferred);
    expect(find.textContaining('We ask women drivers first'), findsOneWidget);
    if (_out.isNotEmpty) {
      await tester.tap(find.text('Women only'));
      await tester.pumpAndSettle();
      await saveScreenshot(tester, _out);
    }
  });

  testWidgets('"Who\'s riding?" checks the name and number, then returns a woman rider', (tester) async {
    await loadTestFonts();
    usePhone(tester, height: 900);
    ({OtherRider? rider})? result;
    await tester.pumpWidget(RepaintBoundary(
      key: shotKey,
      child: MaterialApp(
      theme: RidoTheme.light(),
      home: Scaffold(
        body: RepaintBoundary(
          child: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async => result = await P10bWhoIsRidingSheet.show(context, me: 'Ravi'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Someone else'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Enter their name'), findsOneWidget);
    expect(find.text('Enter their 10-digit mobile number'), findsOneWidget);
    expect(result, isNull);

    await tester.enterText(find.byType(TextField).first, 'Anjali');
    await tester.enterText(find.byKey(const ValueKey('phone-input')), '9876512345');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    if (_outRider.isNotEmpty) await saveScreenshot(tester, _outRider);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result?.rider, const OtherRider(name: 'Anjali', phone: '9876512345', isWoman: true));
  });
}
