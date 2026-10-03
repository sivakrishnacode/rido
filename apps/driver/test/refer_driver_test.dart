// Refer a driver is a plain invite: the Play Store link through WhatsApp or SMS, no referral code, no reward.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_driver/features/account/refer_driver_sheet.dart';
import 'package:tamiltaxi_driver/router/routes.dart';

import 'support/harness.dart';

void main() {
  testWidgets('WhatsApp and SMS send the Play Store link; no code or free days', (tester) async {
    final launched = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
      if (call.method == 'launch') launched.add('${(call.arguments as Map)['url']}');
      return true;
    });
    final container = await pumpRoute(tester, Routes.account);
    await tester.tap(find.text('Refer a driver'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(ReferDriverSheet), findsOneWidget);
    expect(find.textContaining(Seed.referralCode), findsNothing);
    expect(find.textContaining('Free days'), findsNothing);

    await tester.tap(find.text('WhatsApp'));
    await tester.pump();
    await tester.tap(find.text('SMS'));
    await tester.pump();
    expect(launched, hasLength(2));
    expect(launched[0], startsWith('whatsapp://send?text='));
    expect(Uri.decodeComponent(launched[0]), contains(kDriverAppLink));
    expect(launched[1], startsWith('sms:?body='));
    expect(Uri.decodeComponent(launched[1]), contains(kDriverAppLink));
    await closeApp(tester, container);
  });
}
