// P-10 Butterfly (women riders): Any driver / Preferred / Women only, each explained in one line.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_passenger/features/ride/p10_choose_vehicle_screen.dart';
import 'package:rido_ui/rido_ui.dart';

import 'support/harness.dart';

const _out = String.fromEnvironment('OUT');

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
}
