// Contribute page: the monthly cost with its breakdown, amount chips feeding the UPI button, and the
// "open soon" state when no UPI ID is set.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import 'support/harness.dart';

Future<void> _pump(WidgetTester tester, ContributeInfo info, ValueChanged<int?> onPay) async {
  await loadTestFonts();
  usePhone(tester);
  await tester.pumpWidget(MaterialApp(
    theme: RidoTheme.light(),
    home: Scaffold(body: ContributeView(info: info, onPay: onPay)),
  ));
}

void main() {
  testWidgets('shows the monthly cost and breakdown; the chosen amount goes to the UPI button', (tester) async {
    final paid = <int?>[];
    await _pump(tester, AppConfig.demo.contribute, paid.add);

    expect(find.text('₹6,500'), findsOneWidget);
    expect(find.text('Servers & database'), findsOneWidget);
    expect(find.text('Maps'), findsOneWidget);

    await tester.tap(find.text('Contribute ₹50 with UPI'));
    await tester.tap(find.text('₹100'));
    await tester.pump();
    await tester.tap(find.text('Contribute ₹100 with UPI'));
    await tester.tap(find.text('Other amount'));
    await tester.pump();
    await tester.tap(find.text('Contribute with UPI'));
    expect(paid, [50, 100, null]);
  });

  testWidgets('no UPI ID and no cost yet: no pay button, no cost card', (tester) async {
    await _pump(tester, AppConfig.fallback.contribute, (_) {});
    expect(find.text('Contributions open soon.'), findsOneWidget);
    expect(find.byType(RidoButton), findsNothing);
    expect(find.text('What it costs to run'), findsNothing);
  });
}
