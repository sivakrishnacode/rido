import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

void main() {
  testWidgets('picking and removing an attachment updates the actual bytes', (
    tester,
  ) async {
    PhotoAttachment? selected;
    final photo = PhotoAttachment(Uint8List.fromList([1, 2, 3]), 'parcel.jpg');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attachmentPickerProvider.overrideWithValue((_) async => photo),
        ],
        child: MaterialApp(
          theme: TtTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => PhotoAttachmentTile(
                photo: selected,
                onChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.textContaining('Add a photo'));
    await tester.pumpAndSettle();
    expect(selected, same(photo));
    expect(find.text('Photo added'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove photo'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
  });
  testWidgets('countdown freezes and resumes when the accept lock releases', (
    tester,
  ) async {
    bool running = true;
    late StateSetter change;
    await tester.pumpWidget(
      MaterialApp(
        theme: TtTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return CountdownRing(
                duration: const Duration(seconds: 10),
                running: running,
                child: const Text('Offer'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    change(() => running = false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('8s'), findsOneWidget);
    change(() => running = true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('6s'), findsOneWidget);
  });
}
