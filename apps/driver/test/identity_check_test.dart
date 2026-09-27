// D-07 identity step: licence + Aadhaar + selfie run in the app (the SDK is faked), then the result shows.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_driver/features/onboarding/widgets/identity_check_card.dart';
import 'package:rido_ui/rido_ui.dart';

import 'support/harness.dart';

void main() {
  testWidgets('Verify runs the in-app check and shows both documents', (tester) async {
    await loadTestFonts();
    usePhone(tester);
    final tokens = <String>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        identitySdkProvider.overrideWithValue((token) async {
          tokens.add(token);
          return (IdentitySdkOutcome.completed, null);
        }),
      ],
      child: MaterialApp(
        theme: RidoTheme.light(),
        home: const Scaffold(body: Padding(padding: EdgeInsets.all(16), child: IdentityCheckCard())),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Licence, Aadhaar + selfie'), findsOneWidget);
    expect(find.textContaining("Didit's privacy notice", findRichText: true), findsOneWidget);

    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
    expect(tokens, ['mock-token']);
    expect(find.text('Verified · licence •••• 2345 · Aadhaar •••• 7781'), findsOneWidget);
    expect(find.text('Verify'), findsNothing);
    await tester.pump(const Duration(seconds: 5)); // snack timer
  });

  testWidgets('a declined check lists every reason in full', (tester) async {
    await loadTestFonts();
    usePhone(tester);
    const reasons = [
      'Driving licence: this looks like a photo of a screen. Scan the real card, not a photo or a phone / laptop screen',
      'Aadhaar: this looks like a photo of a screen. Scan the real card, not a photo or a phone / laptop screen',
    ];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        identityProvider.overrideWith(() => _Declined(reasons)),
      ],
      child: MaterialApp(
        theme: RidoTheme.light(),
        home: const Scaffold(body: SingleChildScrollView(padding: EdgeInsets.all(16), child: IdentityCheckCard())),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text("We couldn't verify you. Fix this and try again:"), findsOneWidget);
    expect(find.text('Driving licence: This looks like a photo of a screen. Scan the real card, not a photo or a phone / laptop screen.'),
        findsOneWidget);
    expect(find.text('Aadhaar: This looks like a photo of a screen. Scan the real card, not a photo or a phone / laptop screen.'),
        findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}

class _Declined extends IdentityController {
  _Declined(this.reasons);
  final List<String> reasons;

  @override
  Future<IdentityCheck> build() async => IdentityCheck(isEnabled: true, status: IdentityStatus.declined, reasons: reasons);
}
