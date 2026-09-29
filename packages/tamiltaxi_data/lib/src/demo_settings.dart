import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/driver.dart';
import 'models/vehicle.dart';

/// Switches from the Design gallery's "Demo controls" tab. Mock repositories and flow
/// controllers read these so every state can be shown inside the real flow.
@immutable
class DemoSettings {
  const DemoSettings({
    this.fastMode = false,
    // Passenger
    this.noDrivers = false,
    this.driverCancels = false,
    this.offline = false,
    this.locationDenied = false,
    this.outsideServiceArea = false,
    this.emptyActivity = false,
    this.slowLoading = false,
    // Driver
    this.planStatus = PlanStatus.trial,
    this.rejectKyc = false,
    this.accountOnHold = false,
    this.failNextPayment = false,
    this.gpsLost = false,
    this.emptyEarnings = false,
    this.workType = WorkType.rides,
  });

  final bool fastMode;

  final bool noDrivers;
  final bool driverCancels;
  final bool offline;
  final bool locationDenied;
  final bool outsideServiceArea;
  final bool emptyActivity;
  final bool slowLoading;

  final PlanStatus planStatus;
  final bool rejectKyc;
  final bool accountOnHold;
  final bool failNextPayment;
  final bool gpsLost;
  final bool emptyEarnings;
  final WorkType workType;

  DemoSettings copyWith({
    bool? fastMode,
    bool? noDrivers,
    bool? driverCancels,
    bool? offline,
    bool? locationDenied,
    bool? outsideServiceArea,
    bool? emptyActivity,
    bool? slowLoading,
    PlanStatus? planStatus,
    bool? rejectKyc,
    bool? accountOnHold,
    bool? failNextPayment,
    bool? gpsLost,
    bool? emptyEarnings,
    WorkType? workType,
  }) =>
      DemoSettings(
        fastMode: fastMode ?? this.fastMode,
        noDrivers: noDrivers ?? this.noDrivers,
        driverCancels: driverCancels ?? this.driverCancels,
        offline: offline ?? this.offline,
        locationDenied: locationDenied ?? this.locationDenied,
        outsideServiceArea: outsideServiceArea ?? this.outsideServiceArea,
        emptyActivity: emptyActivity ?? this.emptyActivity,
        slowLoading: slowLoading ?? this.slowLoading,
        planStatus: planStatus ?? this.planStatus,
        rejectKyc: rejectKyc ?? this.rejectKyc,
        accountOnHold: accountOnHold ?? this.accountOnHold,
        failNextPayment: failNextPayment ?? this.failNextPayment,
        gpsLost: gpsLost ?? this.gpsLost,
        emptyEarnings: emptyEarnings ?? this.emptyEarnings,
        workType: workType ?? this.workType,
      );
}

class DemoSettingsNotifier extends Notifier<DemoSettings> {
  @override
  DemoSettings build() => const DemoSettings();

  /// Replace all settings, e.g. `update((s) => s.copyWith(noDrivers: true))`.
  void update(DemoSettings Function(DemoSettings s) change) => state = change(state);

  void reset() => state = const DemoSettings();
}

/// Current demo switches. Changes apply immediately.
final demoSettingsProvider = NotifierProvider<DemoSettingsNotifier, DemoSettings>(DemoSettingsNotifier.new);

/// Every simulated delay in one place. Fast mode divides them by 3.
abstract final class SimTimings {
  static const splash = Duration(milliseconds: 1500);

  // Passenger ride
  static const findDriver = Duration(seconds: 3);
  static const driverArrives = Duration(seconds: 5);
  static const driverEntersOtp = Duration(seconds: 4);
  static const rideDuration = Duration(seconds: 12);
  static const reSearchAfterCancel = Duration(seconds: 3);
  static const chatReply = Duration(seconds: 2);
  static const sosContactStagger = Duration(milliseconds: 900);

  // Parcel
  static const findGoodsDriver = Duration(seconds: 3);
  static const goodsDriverReachesPickup = Duration(seconds: 4);
  static const pickupHandover = Duration(seconds: 2);
  static const parcelTransit = Duration(seconds: 12);

  // Driver app
  static const firstRequest = Duration(seconds: 5);
  static const nextRequest = Duration(seconds: 8);
  static const requestCountdown = Duration(seconds: 15);
  static const docVerify = Duration(seconds: 3);
  static const applicationReview = Duration(seconds: 4);
  static const upiProcessing = Duration(seconds: 2);
  static const driverLegDuration = Duration(seconds: 10);

  /// Timer movement tick for vehicle markers.
  static const tick = Duration(milliseconds: 200);

  /// Scales [d] by the fast-mode factor.
  static Duration scaled(Duration d, {required bool fast}) =>
      fast ? Duration(microseconds: d.inMicroseconds ~/ 3) : d;
}

/// Convenience: `ref.read(simTimingProvider)(SimTimings.findDriver)`.
final simTimingProvider = Provider<Duration Function(Duration)>((ref) {
  final fast = ref.watch(demoSettingsProvider.select((s) => s.fastMode));
  return (d) => SimTimings.scaled(d, fast: fast);
});
