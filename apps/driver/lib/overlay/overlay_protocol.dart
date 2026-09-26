import 'package:flutter/foundation.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart' show VehicleKindUi;

/// Messages between the app (main isolate) and the floating overlay (its own engine / isolate, see
/// `overlayMain`), sent with `FlutterOverlayWindow.shareData` as JSON maps. The overlay only draws; every
/// API call stays in the app.
///
/// App → overlay: `{cmd: bubble}` (collapse to the bubble), `{cmd: offer, offer: {…}}` (full-screen request
/// card), `{cmd: accepting}`, `{cmd: error, message}`.
/// Overlay → app: `{action: ready}`, `{action: open}` (bubble tapped), `{action: accept | decline | timeout, id}`.
abstract final class OverlayMsg {
  static const cmd = 'cmd';
  static const action = 'action';

  static const bubble = 'bubble';
  static const offer = 'offer';
  static const accepting = 'accepting';
  static const error = 'error';

  static const ready = 'ready';
  static const open = 'open';
  static const accept = 'accept';
  static const decline = 'decline';
  static const timeout = 'timeout';
}

/// What the overlay's request card shows (a [RideRequest] reduced to JSON-safe values).
@immutable
class OverlayOffer {
  const OverlayOffer({
    required this.id,
    required this.fare,
    required this.vehicle,
    required this.vehicleLabel,
    required this.isDelivery,
    required this.pickupName,
    required this.dropName,
    required this.pickupKm,
    required this.pickupEtaMin,
    required this.tripKm,
    required this.tripMin,
    required this.customerName,
    required this.expiresAtMs,
  });

  factory OverlayOffer.fromRequest(RideRequest r, DateTime expiresAt) => OverlayOffer(
        id: r.id,
        fare: r.fare,
        vehicle: r.vehicle,
        vehicleLabel: r.vehicle.label,
        isDelivery: r.isDelivery,
        pickupName: r.pickup.name,
        dropName: r.drop.name,
        pickupKm: r.pickupDistanceKm,
        pickupEtaMin: r.pickupEtaMin,
        tripKm: r.tripKm,
        tripMin: r.tripMin,
        customerName: r.customerName,
        expiresAtMs: expiresAt.millisecondsSinceEpoch,
      );

  /// Null when [json] isn't an offer (e.g. a message from an older build).
  static OverlayOffer? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    num n(String k) => json[k] is num ? json[k] as num : 0;
    String s(String k) => json[k] is String ? json[k] as String : '';
    return OverlayOffer(
      id: id,
      fare: n('fare').round(),
      vehicle: VehicleKind.values.firstWhere((v) => v.name == json['vehicle'], orElse: () => VehicleKind.bike),
      vehicleLabel: s('vehicleLabel'),
      isDelivery: json['isDelivery'] == true,
      pickupName: s('pickupName'),
      dropName: s('dropName'),
      pickupKm: n('pickupKm').toDouble(),
      pickupEtaMin: n('pickupEtaMin').round(),
      tripKm: n('tripKm').toDouble(),
      tripMin: n('tripMin').round(),
      customerName: s('customerName'),
      expiresAtMs: n('expiresAtMs').round(),
    );
  }

  final String id;
  final int fare;
  final VehicleKind vehicle;
  final String vehicleLabel;
  final bool isDelivery;
  final String pickupName;
  final String dropName;
  final double pickupKm;
  final int pickupEtaMin;
  final double tripKm;
  final int tripMin;
  final String customerName;

  /// When the server moves the offer on (ms since epoch; both isolates share the device clock).
  final int expiresAtMs;

  Duration remaining(DateTime now) {
    final left = Duration(milliseconds: expiresAtMs - now.millisecondsSinceEpoch);
    return left.isNegative ? Duration.zero : left;
  }

  Map<String, Object> toJson() => {
        'id': id,
        'fare': fare,
        'vehicle': vehicle.name,
        'vehicleLabel': vehicleLabel,
        'isDelivery': isDelivery,
        'pickupName': pickupName,
        'dropName': dropName,
        'pickupKm': pickupKm,
        'pickupEtaMin': pickupEtaMin,
        'tripKm': tripKm,
        'tripMin': tripMin,
        'customerName': customerName,
        'expiresAtMs': expiresAtMs,
      };
}

/// What to put over other apps (or in the notification shade) for the live driver session.
enum BackgroundSurface {
  /// App in front, or offline: nothing.
  none,

  /// Online in the background: the floating Rido bubble.
  bubble,

  /// A request while in the background: the full-screen overlay card (plus the ringing notification).
  requestOverlay,

  /// A request while in the background without "Display over other apps": the full-screen-intent
  /// notification, ringing until answered.
  requestNotification,
}

BackgroundSurface backgroundSurfaceFor({
  required bool inBackground,
  required bool online,
  required bool hasRequest,
  required bool overlayAllowed,
}) {
  if (!inBackground || !online) return BackgroundSurface.none;
  if (hasRequest) return overlayAllowed ? BackgroundSurface.requestOverlay : BackgroundSurface.requestNotification;
  return overlayAllowed ? BackgroundSurface.bubble : BackgroundSurface.none;
}
