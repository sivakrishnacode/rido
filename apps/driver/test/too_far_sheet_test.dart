// The "too far from the stop" sheet: Continue anyway stays disabled until a reason is picked (or an
// "Other" note of 3+ characters is typed), and runWithFarCheck retries the step with that reason.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_driver/features/jobs/widgets/too_far_sheet.dart';
import 'package:rido_ui/rido_ui.dart';

import 'support/harness.dart';

const _far = ApiException(
  422,
  "You're 850 m from the pickup point",
  code: 'TOO_FAR',
  details: {'stop': 'pickup', 'distanceM': 850, 'radiusM': 250, 'reasons': ['GPS is wrong', 'Passenger moved']},
);

Future<void> _pumpHost(WidgetTester tester, Future<void> Function(BuildContext) onTap) async {
  await loadTestFonts();
  usePhone(tester);
  await tester.pumpWidget(MaterialApp(
    theme: RidoTheme.light(),
    home: Scaffold(
      body: Builder(builder: (context) => Center(child: TextButton(onPressed: () => onTap(context), child: const Text('go')))),
    ),
  ));
}

RidoButton _continue(WidgetTester tester) =>
    tester.widget<RidoButton>(find.widgetWithText(RidoButton, 'Continue anyway'));

void main() {
  test('formatMetres', () {
    expect(formatMetres(850), '850 m');
    expect(formatMetres(1234), '1.2 km');
  });

  testWidgets('a far step asks for a reason, then retries with it', (tester) async {
    final reasons = <String?>[];
    bool? result;
    await _pumpHost(tester, (context) async {
      result = await runWithFarCheck(context, (r) async {
        reasons.add(r);
        if (r == null) throw _far;
      }, target: const LatLng(11, 77));
    });
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text("You're 850 m from the pickup point"), findsOneWidget);
    expect(find.text('Navigate to pickup'), findsOneWidget);
    expect(_continue(tester).onPressed, isNull);

    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    expect(_continue(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'ok');
    await tester.pump();
    expect(_continue(tester).onPressed, isNull, reason: 'under 3 characters');
    await tester.enterText(find.byType(TextField), 'Gate is closed');
    await tester.pump();
    expect(_continue(tester).onPressed, isNotNull);

    await tester.tap(find.text('Passenger moved'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue anyway'));
    await tester.pumpAndSettle();
    expect(reasons, [null, 'Passenger moved']);
    expect(result, isTrue);
  });

  testWidgets('Cancel backs out without retrying', (tester) async {
    final reasons = <String?>[];
    bool? result;
    await _pumpHost(tester, (context) async {
      result = await runWithFarCheck(context, (r) async {
        reasons.add(r);
        throw _far;
      }, target: const LatLng(11, 77));
    });
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(reasons, [null]);
    expect(result, isFalse);
  });

  testWidgets('other API errors pass through', (tester) async {
    Object? error;
    await _pumpHost(tester, (context) async {
      try {
        await runWithFarCheck(context, (_) async => throw const ApiException(400, 'Wrong OTP, please try again'),
            target: const LatLng(11, 77));
      } catch (e) {
        error = e;
      }
    });
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(error, isA<ApiException>());
    expect(find.byType(TooFarSheet), findsNothing);
  });
}
