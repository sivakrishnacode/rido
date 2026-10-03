// D-19 collect payment: the UPI QR is the driver's own, never the demo one. Live with no UPI ID (or none loaded yet)
// there is no QR, just a hint to collect cash.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_driver/features/home/d13_home_screen.dart';
import 'package:tamiltaxi_driver/features/jobs/d19_collect_payment_screen.dart';
import 'package:tamiltaxi_driver/features/jobs/widgets/rate_customer_sheet.dart';
import 'package:tamiltaxi_driver/router/routes.dart';
import 'package:tamiltaxi_driver/state/driver_account.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import 'support/harness.dart';
import 'support/live_fakes.dart';

class _Profile extends DriverProfileController {
  _Profile(this.profile);
  final DriverProfile profile;
  @override
  Future<DriverProfile> build() async => profile;
}

Future<void> _pump(WidgetTester tester, {required bool live, required DriverProfile profile}) async {
  await loadTestFonts();
  usePhone(tester);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      isLiveApiProvider.overrideWithValue(live),
      driverProfileProvider.overrideWith(() => _Profile(profile)),
    ],
    child: RepaintBoundary(
      key: shotKey,
      child: MaterialApp(theme: TtTheme.light(), home: D19CollectPaymentScreen(sample: Seed.rideRequest)),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('live with no UPI ID: no QR, collect cash instead', (tester) async {
    await _pump(tester, live: true, profile: Seed.karthik.copyWith(upiId: ''));
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('No UPI ID yet'), findsOneWidget);
    expect(find.text(Seed.karthik.upiId), findsNothing);
    expect(find.text('Received cash'), findsOneWidget);
  });

  testWidgets("live: the QR pays the driver's own UPI ID", (tester) async {
    await _pump(tester, live: true, profile: Seed.karthik.copyWith(upiId: 'priya@oksbi'));
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('priya@oksbi'), findsOneWidget);
  });

  testWidgets('live: Received cash goes straight Home, no rating sheet (there is no API for it)', (tester) async {
    final rig = await LiveRig.create(prefs: {'tamiltaxi.accessToken': 'token', 'tamiltaxi.driverId': 'd1'});
    final container = await pumpRoute(tester, Routes.collect, overrides: rig.overrides);
    await tester.tap(find.text('Received cash'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(RateCustomerSheet), findsNothing);
    expect(find.byType(D13HomeScreen), findsOneWidget);
    await closeApp(tester, container);
  });

  testWidgets('demo: the rating sheet still shows', (tester) async {
    final container = await pumpRoute(tester, Routes.collect);
    await tester.tap(find.text('Received cash'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(RateCustomerSheet), findsOneWidget);
    await closeApp(tester, container);
  });
}
