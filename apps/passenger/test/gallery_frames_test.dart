// Opens EVERY frame listed in the Design gallery through its real route
// (/gallery/view/<id>) and asserts it builds without exceptions or overflow errors,
// at the narrowest and widest supported phone widths.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_passenger/features/design_gallery/gallery_registry.dart';
import 'package:rido_passenger/router/routes.dart';

import 'support/harness.dart';

void main() {
  test('gallery lists frames', () => expect(galleryEntries, isNotEmpty));

  for (final width in [360.0, 430.0]) {
    for (final entry in galleryEntries) {
      testWidgets('${entry.id} ${entry.name} builds at ${width.toInt()}px', (tester) async {
        await pumpRoute(tester, Routes.galleryView(entry.id), width: width);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull, reason: '${entry.id} threw while building');
        expect(find.text('Frame not found'), findsNothing);
        // Unmount and let any timers the frame started run out.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(minutes: 1));
      });
    }
  }
}
