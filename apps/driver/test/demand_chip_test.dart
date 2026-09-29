import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_driver/features/home/widgets/demand_chip.dart';
import 'package:tamiltaxi_driver/features/home/widgets/demand_layer.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

const _ring = [LatLng(11, 76.9), LatLng(11.1, 76.9), LatLng(11.1, 77)];

Hotspot _h(String cell, HotspotLevel level, LatLng c, {String? name, double m = 1}) =>
    Hotspot(cell: cell, level: level, score: 1, multiplier: m, centre: c, boundary: _ring, name: name);

void main() {
  const me = LatLng(11.0168, 76.9558);

  test('suggests the nearest high-demand area, else the nearest busy one, never a quiet one', () {
    final map = DemandMap(at: DateTime(2026, 9, 28), hotspots: [
      _h('far-high', HotspotLevel.high, const LatLng(11.10, 76.96)),
      _h('near-high', HotspotLevel.high, const LatLng(11.03, 76.96)),
      _h('nearest-busy', HotspotLevel.busy, const LatLng(11.017, 76.956)),
    ]);
    expect(nearestHotspot(map, me)!.hotspot.cell, 'near-high');

    final busyOnly = DemandMap(at: DateTime(2026, 9, 28), hotspots: [
      _h('busy', HotspotLevel.busy, const LatLng(11.05, 76.96)),
      _h('quiet', HotspotLevel.some, const LatLng(11.017, 76.956)),
    ]);
    expect(nearestHotspot(busyOnly, me)!.hotspot.cell, 'busy');

    final quiet = DemandMap(at: DateTime(2026, 9, 28), hotspots: [_h('q', HotspotLevel.some, me)]);
    expect(nearestHotspot(quiet, me), isNull);
    expect(nearestHotspot(map, null), isNull);
  });

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
        MaterialApp(theme: TtTheme.light(), home: Scaffold(body: child)),
      );

  testWidgets('shows the area, surge and distance; directions opens navigation', (tester) async {
    var tapped = false;
    await pump(
      tester,
      NearestDemandChip(
        hotspot: _h('a', HotspotLevel.high, me, name: 'Gandhipuram', m: 1.2),
        km: 2.4,
        onDirections: () => tapped = true,
      ),
    );
    expect(find.text('HIGH DEMAND · 1.2x'), findsOneWidget);
    expect(find.text('Gandhipuram'), findsOneWidget);
    expect(find.text('2.4 km'), findsOneWidget);
    await tester.tap(find.text('2.4 km'));
    expect(tapped, isTrue);
  });

  testWidgets('inside the area: no directions button', (tester) async {
    await pump(tester, NearestDemandChip(hotspot: _h('a', HotspotLevel.busy, me), km: 0.4, onDirections: () {}));
    expect(find.text('BUSY AREA'), findsOneWidget);
    expect(find.text("You're here"), findsOneWidget);
    expect(find.byIcon(Symbols.turn_right_rounded), findsNothing);
  });

  test('the API name is parsed and blank names are dropped', () {
    Map<String, dynamic> j(String? name) => {
          'at': '2026-09-28T10:00:00Z',
          'hotspots': [
            {'cell': 'a', 'level': 'high', 'centre': [11, 77], 'boundary': [], 'name': name},
          ],
        };
    expect(DemandMap.fromJson(j('Peelamedu')).hotspots.single.name, 'Peelamedu');
    expect(DemandMap.fromJson(j('  ')).hotspots.single.name, isNull);
    expect(DemandMap.fromJson(j(null)).hotspots.single.name, isNull);
  });
}
