// Profile photo preview: the driver sees their card as riders will (photo, name, rating, vehicle, plate).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_driver/features/onboarding/profile_photo_screen.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import 'support/harness.dart';

void main() {
  testWidgets('the preview shows the rider card with the new photo', (tester) async {
    await loadTestFonts();
    usePhone(tester);
    // 1×1 transparent PNG.
    final png = Uint8List.fromList(const [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, //
      0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, //
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);
    await tester.pumpWidget(MaterialApp(
      theme: TtTheme.light(),
      home: Scaffold(body: RiderPreviewCard(profile: Seed.karthik, photo: MemoryImage(png))),
    ));
    await tester.pumpAndSettle();
    expect(find.text(Seed.karthik.name), findsOneWidget);
    expect(find.text(Seed.karthik.vehicleLabel), findsOneWidget);
    expect(find.byType(NumberPlate), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Preview of your card in the rider app')), findsOneWidget);
  });
}
