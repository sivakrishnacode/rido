// The floating overlay's protocol: which surface shows in the background, and the request card data that
// crosses isolates as JSON.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_driver/overlay/overlay_protocol.dart';

void main() {
  group('backgroundSurfaceFor', () {
    BackgroundSurface f({bool bg = true, bool online = true, bool request = false, bool allowed = true}) =>
        backgroundSurfaceFor(inBackground: bg, online: online, hasRequest: request, overlayAllowed: allowed);

    test('nothing in front or offline', () {
      expect(f(bg: false), BackgroundSurface.none);
      expect(f(bg: false, request: true), BackgroundSurface.none);
      expect(f(online: false), BackgroundSurface.none);
      expect(f(online: false, request: true), BackgroundSurface.none);
    });

    test('online in the background: the bubble, or nothing without the permission', () {
      expect(f(), BackgroundSurface.bubble);
      expect(f(allowed: false), BackgroundSurface.none);
    });

    test('a request: the overlay card, or the full-screen notification without the permission', () {
      expect(f(request: true), BackgroundSurface.requestOverlay);
      expect(f(request: true, allowed: false), BackgroundSurface.requestNotification);
    });
  });

  group('OverlayOffer', () {
    final expires = DateTime(2026, 9, 26, 10, 0, 15);
    final r = Seed.deliveryRequest.copyWith(id: 'trip-9', customerName: 'Meena', pickupDistanceKm: 1.4, pickupEtaMin: 5);

    test('survives the JSON trip between isolates', () {
      final json = jsonDecode(jsonEncode(OverlayOffer.fromRequest(r, expires).toJson()));
      final o = OverlayOffer.fromJson(json)!;
      expect(o.id, 'trip-9');
      expect(o.fare, r.fare);
      expect(o.vehicle, r.vehicle);
      expect(o.isDelivery, isTrue);
      expect(o.pickupName, r.pickup.name);
      expect(o.dropName, r.drop.name);
      expect(o.pickupKm, 1.4);
      expect(o.pickupEtaMin, 5);
      expect(o.customerName, 'Meena');
      expect(o.expiresAtMs, expires.millisecondsSinceEpoch);
    });

    test('countdown from the server expiry, never negative', () {
      final o = OverlayOffer.fromRequest(r, expires);
      expect(o.remaining(DateTime(2026, 9, 26, 10, 0, 5)), const Duration(seconds: 10));
      expect(o.remaining(DateTime(2026, 9, 26, 10, 1)), Duration.zero);
    });

    test('rejects non-offers', () {
      expect(OverlayOffer.fromJson(null), isNull);
      expect(OverlayOffer.fromJson({'fare': 10}), isNull);
      expect(OverlayOffer.fromJson('x'), isNull);
    });
  });
}
