import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_passenger/common/add_extra_card.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import 'support/harness.dart';

void main() {
  Future<List<int>> pump(WidgetTester tester, {required int total, int extra = 0}) async {
    await loadTestFonts();
    usePhone(tester);
    final added = <int>[];
    await tester.pumpWidget(MaterialApp(
      theme: TtTheme.light(),
      home: Scaffold(body: AddExtraCard(total: total, extra: extra, busy: false, onAdd: added.add)),
    ));
    return added;
  }

  testWidgets('pick +₹20, see the new fare, add it: the extra in all is sent', (tester) async {
    final added = await pump(tester, total: 50);
    expect(find.text('No driver yet? Add a little extra'), findsOneWidget);
    expect(find.text('Add ₹20 · ₹70 in all'), findsNothing, reason: 'nothing is added by a single tap');
    await tester.tap(find.text('+₹20'));
    await tester.pump();
    await tester.tap(find.text('Add ₹20 · ₹70 in all'));
    expect(added, [20]);
  });

  testWidgets('after an extra: more is added on top, never past the cap', (tester) async {
    final added = await pump(tester, total: 70, extra: 20);
    expect(find.text('₹20 extra added'), findsOneWidget);
    expect(find.textContaining('Drivers now see ₹50 + ₹20'), findsOneWidget);
    await tester.tap(find.text('+₹10'));
    await tester.pump();
    await tester.tap(find.text('Add ₹10 · ₹80 in all'));
    expect(added, [30]);

    // ₹35 fare, ₹80 already added: the cap is ₹100, so only +₹10 and +₹20 are left.
    await pump(tester, total: 115, extra: 80);
    expect(find.text('+₹10'), findsOneWidget);
    expect(find.text('+₹20'), findsOneWidget);
    expect(find.text('+₹30'), findsNothing);
    expect(FareEngine.maxExtra(35), 100);
  });

  testWidgets('at the cap: no more steps', (tester) async {
    await pump(tester, total: 135, extra: 100);
    expect(find.byType(TtChip), findsNothing);
    expect(find.textContaining("That's the most you can add."), findsOneWidget);
  });
}
