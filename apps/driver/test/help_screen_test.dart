// Help & support: WhatsApp opens a chat with the support number, Call dials it, and the recent-trip card raises a
// ticket about that trip.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_driver/features/account/driver_help_screen.dart';
import 'package:tamiltaxi_driver/features/account/driver_new_ticket_screen.dart';
import 'package:tamiltaxi_driver/router/routes.dart';

import 'support/harness.dart';

void main() {
  test('a ticket route carries the topic and the trip', () {
    expect(Routes.newTicket(), '/help/new-ticket');
    expect(Routes.newTicket(topic: 'Payment issue', tripId: 't 1'), '/help/new-ticket?topic=Payment%20issue&tripId=t%201');
  });

  testWidgets('WhatsApp and Call use the support number', (tester) async {
    final launched = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
      if (call.method == 'launch') launched.add('${(call.arguments as Map)['url']}');
      return true;
    });
    final container = await pumpRoute(tester, Routes.help);
    expect(find.byType(DriverHelpScreen), findsOneWidget);

    await tester.tap(find.text('WhatsApp'));
    await tester.pump();
    await tester.tap(find.text('Call'));
    await tester.pump();
    expect(launched, ['https://wa.me/914220000000', 'tel:+914220000000']);
    await closeApp(tester, container);
  });

  testWidgets('the recent trip opens a ticket about it', (tester) async {
    final container = await pumpRoute(tester, Routes.help);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Get help'), findsOneWidget);
    await tester.tap(find.text('Get help'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final uri = GoRouterState.of(tester.element(find.byType(DriverNewTicketScreen))).uri;
    expect(uri.path, '/help/new-ticket');
    expect(uri.queryParameters['tripId'], isNotEmpty);
    await closeApp(tester, container);
  });
}
