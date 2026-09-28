import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_driver/features/jobs/widgets/request_flow.dart';
import 'package:rido_driver/state/driver_session.dart';
import 'package:rido_ui/rido_ui.dart';

void main() {
  testWidgets('other open requests show as chips with fare and pickup distance; a tap focuses one', (tester) async {
    final soon = DateTime.now().add(const Duration(seconds: 12));
    final a = Seed.rideRequest.copyWith(id: 'a', fare: 120);
    final b = Seed.rideRequest.copyWith(id: 'b', fare: 90);
    String? focused;
    await tester.pumpWidget(MaterialApp(
      theme: RidoTheme.light(),
      home: Scaffold(
        backgroundColor: RidoColors.coral600,
        body: RequestStackChips(queued: [QueuedOffer(a, soon), QueuedOffer(b, soon)], onFocus: (id) => focused = id),
      ),
    ));
    expect(find.text('+2 more'), findsOneWidget);
    expect(find.text('₹120'), findsOneWidget);
    expect(find.text('₹90'), findsOneWidget);
    await tester.tap(find.text('₹90'));
    expect(focused, 'b');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no other requests: nothing shown', (tester) async {
    await tester.pumpWidget(MaterialApp(home: RequestStackChips(queued: const [], onFocus: (_) {})));
    expect(find.textContaining('more'), findsNothing);
  });
}
