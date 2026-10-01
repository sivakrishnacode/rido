import 'package:flutter/foundation.dart';

import 'fare_engine.dart';
import 'models/place.dart';
import 'models/vehicle.dart';
import 'ride_modes.dart';
import 'seed.dart';

/// House shifting: how big the home is (sets the suggested vehicle, helpers, packing and unpacking prices).
enum HomeSize {
  fewItems('A few items', 'A fridge, a cot, some cartons', 'FEW_ITEMS'),
  oneRk('Studio / 1 RK', 'One room and a kitchen', 'ONE_RK'),
  oneBhk('1 BHK', 'One bedroom home', 'ONE_BHK'),
  twoBhk('2 BHK', 'Two bedroom home', 'TWO_BHK'),
  threeBhk('3 BHK or more', 'Three bedrooms and up', 'THREE_BHK');

  const HomeSize(this.label, this.hint, this.api);
  final String label;
  final String hint;
  final String api;

  static HomeSize fromApi(Object? s) => values.firstWhere((v) => v.api == s, orElse: () => oneBhk);
}

/// Packing the movers bring: none (packed already), basic (wrap and tape) or full (boxes, wrap, bubble for the fragile).
enum PackingLevel {
  none('I\'ll pack', 'Everything is packed and ready', 'NONE'),
  basic('Basic', 'Wrap and tape for furniture and appliances', 'BASIC'),
  full('Full', 'Boxes, wrap and bubble for the fragile, all packed for you', 'FULL');

  const PackingLevel(this.label, this.hint, this.api);
  final String label;
  final String hint;
  final String api;

  static PackingLevel fromApi(Object? s) => values.firstWhere((v) => v.api == s, orElse: () => none);
}

/// One thing to move, as the rider typed it: "Double cot", 1, "comes apart".
@immutable
class ShiftingItem {
  const ShiftingItem({required this.name, this.qty = 1, this.note = ''});

  final String name;
  final int qty;
  final String note;

  ShiftingItem copyWith({String? name, int? qty, String? note}) =>
      ShiftingItem(name: name ?? this.name, qty: qty ?? this.qty, note: note ?? this.note);

  Map<String, Object> toJson() => {'name': name.trim(), 'qty': qty, if (note.trim().isNotEmpty) 'note': note.trim()};

  static ShiftingItem fromJson(Map<String, dynamic> j) =>
      ShiftingItem(name: '${j['name'] ?? ''}', qty: j['qty'] is num ? (j['qty'] as num).toInt() : 1, note: '${j['note'] ?? ''}');

  @override
  bool operator ==(Object other) => other is ShiftingItem && other.name == name && other.qty == qty && other.note == note;

  @override
  int get hashCode => Object.hash(name, qty, note);
}

/// The price lines of a house shift (whole rupees, each rounded down), the API's `ShiftingLines`.
@immutable
class ShiftingLines {
  const ShiftingLines({
    required this.transport,
    required this.helperCount,
    required this.helpers,
    required this.stairs,
    required this.packing,
    required this.dismantle,
    required this.unpack,
    required this.subtotal,
    required this.weekend,
    required this.total,
  });

  final int transport;
  final int helperCount;
  final int helpers;
  final int stairs;
  final int packing;
  final int dismantle;
  final int unpack;
  final int subtotal;

  /// Saturday / Sunday: [GoodsModeRates.weekendPct] % of the subtotal.
  final int weekend;
  final int total;

  static ShiftingLines? fromJson(Object? raw) {
    if (raw is! Map) return null;
    int n(String k) => raw[k] is num ? (raw[k] as num).toInt() : 0;
    return ShiftingLines(
      transport: n('transport'),
      helperCount: n('helperCount'),
      helpers: n('helpers'),
      stairs: n('stairs'),
      packing: n('packing'),
      dismantle: n('dismantle'),
      unpack: n('unpack'),
      subtotal: n('subtotal'),
      weekend: n('weekend'),
      total: n('total'),
    );
  }

  Map<String, int> toJson() => {
        'transport': transport,
        'helperCount': helperCount,
        'helpers': helpers,
        'stairs': stairs,
        'packing': packing,
        'dismantle': dismantle,
        'unpack': unpack,
        'subtotal': subtotal,
        'weekend': weekend,
        'total': total,
      };
}

/// What the movers are asked to do (`Trip.shifting`): the home, the items as typed, both ends' floors and lifts,
/// packing and extras; [lines] once priced (a booked trip).
@immutable
class ShiftingDetails {
  const ShiftingDetails({
    this.homeSize = HomeSize.oneBhk,
    this.between = false,
    this.items = const [],
    this.pickupFloor = 0,
    this.pickupLift = false,
    this.dropFloor = 0,
    this.dropLift = false,
    this.packing = PackingLevel.none,
    this.dismantlePieces = 0,
    this.unpack = false,
    this.extraHelpers = 0,
    this.lines,
  });

  final HomeSize homeSize;

  /// To another town: helpers at the travel rate, the vehicle by the km.
  final bool between;
  final List<ShiftingItem> items;
  final int pickupFloor;
  final bool pickupLift;
  final int dropFloor;
  final bool dropLift;
  final PackingLevel packing;
  final int dismantlePieces;
  final bool unpack;
  final int extraHelpers;
  final ShiftingLines? lines;

  /// Everything counted: "14 items".
  int get itemCount => items.fold(0, (n, i) => n + i.qty);

  ShiftingDetails copyWith({
    HomeSize? homeSize,
    bool? between,
    List<ShiftingItem>? items,
    int? pickupFloor,
    bool? pickupLift,
    int? dropFloor,
    bool? dropLift,
    PackingLevel? packing,
    int? dismantlePieces,
    bool? unpack,
    int? extraHelpers,
    ShiftingLines? lines,
  }) =>
      ShiftingDetails(
        homeSize: homeSize ?? this.homeSize,
        between: between ?? this.between,
        items: items ?? this.items,
        pickupFloor: pickupFloor ?? this.pickupFloor,
        pickupLift: pickupLift ?? this.pickupLift,
        dropFloor: dropFloor ?? this.dropFloor,
        dropLift: dropLift ?? this.dropLift,
        packing: packing ?? this.packing,
        dismantlePieces: dismantlePieces ?? this.dismantlePieces,
        unpack: unpack ?? this.unpack,
        extraHelpers: extraHelpers ?? this.extraHelpers,
        lines: lines ?? this.lines,
      );

  /// The API's `shifting` body ([withItems]: to book; a quote doesn't need them).
  Map<String, Object> toJson({bool withItems = true}) => {
        'homeSize': homeSize.api,
        'between': between,
        if (withItems) 'items': [for (final i in items) i.toJson()],
        'pickupFloor': pickupFloor,
        'pickupLift': pickupLift,
        'dropFloor': dropFloor,
        'dropLift': dropLift,
        'packing': packing.api,
        'dismantlePieces': dismantlePieces,
        'unpack': unpack,
        'extraHelpers': extraHelpers,
      };

  static ShiftingDetails? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    int n(String k) => j[k] is num ? (j[k] as num).toInt() : 0;
    return ShiftingDetails(
      homeSize: HomeSize.fromApi(j['homeSize']),
      between: j['between'] == true,
      items: [
        for (final i in (j['items'] as List?) ?? const [])
          if (i is Map) ShiftingItem.fromJson(i.cast<String, dynamic>()),
      ],
      pickupFloor: n('pickupFloor'),
      pickupLift: j['pickupLift'] == true,
      dropFloor: n('dropFloor'),
      dropLift: j['dropLift'] == true,
      packing: PackingLevel.fromApi(j['packing']),
      dismantlePieces: n('dismantlePieces'),
      unpack: j['unpack'] == true,
      extraHelpers: n('extraHelpers'),
      lines: ShiftingLines.fromJson(j['lines']),
    );
  }
}

/// "Ground floor", "2nd floor · no lift", "5th floor · lift".
String floorLabel(int floor, bool lift) {
  if (floor <= 0) return 'Ground floor';
  final suffix = (floor % 100 >= 11 && floor % 100 <= 13)
      ? 'th'
      : switch (floor % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$floor$suffix floor · ${lift ? 'lift' : 'no lift'}';
}

/// A house shift priced for one vehicle and slot, with every goods truck's total and the next 7 days' totals.
@immutable
class ShiftingQuote {
  const ShiftingQuote({
    required this.vehicle,
    required this.distanceKm,
    required this.durationMin,
    required this.lines,
    this.modeTerms,
    this.vehicles = const [],
    this.days = const [],
  });

  final VehicleKind vehicle;
  final double distanceKm;
  final int durationMin;
  final ShiftingLines lines;

  /// To another town: the vehicle's one-way terms.
  final OutstationTerms? modeTerms;
  final List<({VehicleKind kind, int total, bool suggested})> vehicles;

  /// IST calendar dates (local midnight here) and their totals; weekends cost more.
  final List<({DateTime date, int total, bool weekend})> days;
}

/// Goods to another town and house shifting, the same rates as the API's `fares/goods-modes.ts` (shared cases in
/// test/fixtures/goods_mode_cases.json). Used by mock mode; the live app shows the API's quotes.
abstract final class GoodsModeRates {
  /// Go to other towns and do house shifting (not the goods bike).
  static const goodsTrucks = [VehicleKind.threeWheeler, VehicleKind.miniTruck, VehicleKind.pickup, VehicleKind.truck];

  static const Map<VehicleKind, ({double perKm, int minKm})> outstation = {
    VehicleKind.threeWheeler: (perKm: 22, minKm: 40),
    VehicleKind.miniTruck: (perKm: 26, minKm: 40),
    VehicleKind.pickup: (perKm: 30, minKm: 40),
    VehicleKind.truck: (perKm: 45, minKm: 40),
  };

  static const Map<HomeSize, ({VehicleKind vehicle, int helpers, int basic, int full, int unpack})> sizes = {
    HomeSize.fewItems: (vehicle: VehicleKind.threeWheeler, helpers: 1, basic: 199, full: 399, unpack: 149),
    HomeSize.oneRk: (vehicle: VehicleKind.miniTruck, helpers: 2, basic: 399, full: 799, unpack: 299),
    HomeSize.oneBhk: (vehicle: VehicleKind.pickup, helpers: 2, basic: 699, full: 1299, unpack: 499),
    HomeSize.twoBhk: (vehicle: VehicleKind.truck, helpers: 3, basic: 999, full: 1899, unpack: 699),
    HomeSize.threeBhk: (vehicle: VehicleKind.truck, helpers: 4, basic: 1499, full: 2699, unpack: 999),
  };

  static const helperCity = 450;
  static const helperBetween = 700;
  static const stairsPerFloor = 150;
  static const dismantlePerPiece = 199;
  static const weekendPct = 10;
  static const maxExtraHelpers = 4;
  static const maxDismantlePieces = 10;
  static const maxFloor = 30;
  static const maxItems = 60;

  /// Two-hour slots (start hours, IST): 7–9 am … 4–6 pm.
  static const slotHours = [7, 9, 11, 14, 16];

  /// A slot starts at least this far ahead (movers need time to come with helpers).
  static const leadTime = Duration(hours: 1);

  static bool isGoodsTruck(VehicleKind k) => goodsTrucks.contains(k);

  static OutstationTerms outstationTerms(VehicleKind kind, double routeKm) {
    final r = outstation[kind]!;
    final km = (routeKm * 10).round() / 10;
    return OutstationTerms(
      roundTrip: false,
      returnAt: null,
      days: 1,
      includedKm: km.ceil() < r.minKm ? r.minKm : km.ceil(),
      perKm: r.perKm,
      allowancePerDay: 0,
      routeKm: km,
    );
  }

  /// Mock mode: the goods trucks one way to [drop] on the local route estimate.
  static List<FareQuote> outstationQuotes(Place pickup, Place drop) {
    final route = FareEngine.estimate(pickup, drop);
    return [
      for (final k in goodsTrucks)
        RideModeRates.quote(Seed.vehicle(k), outstationTerms(k, route.distanceKm),
            distanceKm: route.distanceKm, durationMin: route.durationMin),
    ];
  }

  /// Saturday or Sunday in India at [at].
  static bool isIstWeekend(DateTime at) {
    final ist = at.toUtc().add(const Duration(minutes: 330));
    return ist.weekday == DateTime.saturday || ist.weekday == DateTime.sunday;
  }

  static int _stairs(int floor, bool lift) => lift || floor < 0 ? 0 : floor;

  /// The lines for [d] with the vehicle's [transport] price, on the day of [at].
  static ShiftingLines lines(ShiftingDetails d, int transport, DateTime at) {
    final size = sizes[d.homeSize]!;
    final helperCount = size.helpers + d.extraHelpers.clamp(0, maxExtraHelpers);
    final helpers = helperCount * (d.between ? helperBetween : helperCity);
    final stairs = (_stairs(d.pickupFloor, d.pickupLift) + _stairs(d.dropFloor, d.dropLift)) * stairsPerFloor;
    final packing = switch (d.packing) {
      PackingLevel.none => 0,
      PackingLevel.basic => size.basic,
      PackingLevel.full => size.full,
    };
    final dismantle = d.dismantlePieces.clamp(0, maxDismantlePieces) * dismantlePerPiece;
    final unpack = d.unpack ? size.unpack : 0;
    final subtotal = transport + helpers + stairs + packing + dismantle + unpack;
    final weekend = isIstWeekend(at) ? subtotal * weekendPct ~/ 100 : 0;
    return ShiftingLines(
      transport: transport,
      helperCount: helperCount,
      helpers: helpers,
      stairs: stairs,
      packing: packing,
      dismantle: dismantle,
      unpack: unpack,
      subtotal: subtotal,
      weekend: weekend,
      total: subtotal + weekend,
    );
  }

  /// [hour] o'clock on the calendar day [dayOffset] days after [now]'s (the device's day; the app runs in India).
  static DateTime dayAt(DateTime now, int dayOffset, int hour) => DateTime(now.year, now.month, now.day + dayOffset, hour);

  /// Mock mode: [d] by [vehicle] (default: the one suggested for the size) at the slot [at], priced like the API
  /// (in town: the goods fare on the local route estimate, no surge; to another town: by the km).
  static ShiftingQuote quote(Place pickup, Place drop, ShiftingDetails d, {VehicleKind? vehicle, required DateTime at, DateTime? now}) {
    final suggested = sizes[d.homeSize]!.vehicle;
    final kind = vehicle ?? suggested;
    final route = FareEngine.estimate(pickup, drop);
    int transportOf(VehicleKind k) => d.between
        ? (outstationTerms(k, route.distanceKm).includedKm * outstation[k]!.perKm).floor()
        : FareEngine.quote(Seed.vehicle(k), route, multiplier: 1).total;
    final transport = transportOf(kind);
    final today = now ?? DateTime.now();
    return ShiftingQuote(
      vehicle: kind,
      distanceKm: route.distanceKm,
      durationMin: route.durationMin,
      lines: lines(d, transport, at),
      modeTerms: d.between ? outstationTerms(kind, route.distanceKm) : null,
      vehicles: [
        for (final k in goodsTrucks) (kind: k, total: lines(d, transportOf(k), at).total, suggested: k == suggested),
      ],
      days: [
        for (var i = 0; i < 7; i++)
          () {
            final dayAt9 = dayAt(today, i, 9);
            final l = lines(d, transport, dayAt9);
            return (date: DateTime(dayAt9.year, dayAt9.month, dayAt9.day), total: l.total, weekend: l.weekend > 0);
          }(),
      ],
    );
  }
}
