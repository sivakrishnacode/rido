// Account › Verify identity: optional in-app check (the SDK is faked); approval shows the Verified state.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_passenger/features/account/verify_identity_screen.dart';
import 'package:rido_ui/rido_ui.dart';

import 'support/harness.dart';

void main() {
  testWidgets('Verify now runs the check in the app, then shows the badge state', (tester) async {
    await loadTestFonts();
    usePhone(tester);
    var launches = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        identitySdkProvider.overrideWithValue((_) async {
          launches++;
          return (IdentitySdkOutcome.completed, null);
        }),
      ],
      child: MaterialApp(theme: RidoTheme.light(), home: const VerifyIdentityScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Get a Verified badge'), findsOneWidget);

    await tester.tap(find.text('Verify now'));
    await tester.pumpAndSettle();
    expect(launches, 1);
    expect(find.text("You're verified"), findsOneWidget);
    expect(find.text('Verify now'), findsNothing);
  });

  testWidgets('a declined check shows the reason and Try again', (tester) async {
    await loadTestFonts();
    usePhone(tester);
    final container = ProviderContainer(overrides: [
      identitySdkProvider.overrideWithValue((_) async => (IdentitySdkOutcome.completed, null)),
    ]);
    addTearDown(container.dispose);
    container.read(demoSettingsProvider.notifier).update((s) => s.copyWith(rejectKyc: true));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: RidoTheme.light(), home: const VerifyIdentityScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify now'));
    await tester.pumpAndSettle();
    expect(find.text("We couldn't verify you"), findsOneWidget);
    expect(find.text("Selfie: Your selfie doesn't match the photo on the ID. Retake it in good light."), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
