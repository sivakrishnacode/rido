import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';

/// The signed-in driver's profile (Karthik by default).
class DriverProfileController extends AsyncNotifier<DriverProfile> {
  @override
  Future<DriverProfile> build() {
    ref.watch(mockDatabaseProvider);
    return ref.read(driverRepositoryProvider).profile();
  }

  Future<void> save(DriverProfile p) async {
    state = AsyncData(p);
    await ref.read(driverRepositoryProvider).updateProfile(p);
  }
}

final driverProfileProvider =
    AsyncNotifierProvider<DriverProfileController, DriverProfile>(DriverProfileController.new);

/// KYC checklist (D-07). Uploading sets "Under review", then "Verified" after 3 s.
class KycController extends AsyncNotifier<List<KycDocument>> {
  final TripSimulator _timers = TripSimulator();

  @override
  Future<List<KycDocument>> build() {
    ref.watch(mockDatabaseProvider);
    ref.onDispose(_timers.cancelAll);
    return ref.read(driverRepositoryProvider).kycDocuments();
  }

  Future<void> upload(KycDocType type) async {
    final repo = ref.read(driverRepositoryProvider);
    state = AsyncData(await repo.setKycStatus(type, KycStatus.underReview));
    _timers.after(ref.read(simTimingProvider)(SimTimings.docVerify), () async {
      final docs = await repo.setKycStatus(type, KycStatus.verified);
      state = AsyncData(docs);
    });
  }

  /// D-10 check: approved → all verified; rejected → Vehicle RC rejected (S-09).
  Future<bool> checkApplication() async {
    final ok = await ref.read(driverRepositoryProvider).checkApplication();
    state = AsyncData(await ref.read(driverRepositoryProvider).kycDocuments());
    return ok;
  }
}

final kycProvider = AsyncNotifierProvider<KycController, List<KycDocument>>(KycController.new);

/// The driver's plan. Follows Demo control "Plan status" and the Pause / Cancel / Pay actions.
class PlanController extends AsyncNotifier<SubscriptionPlan> {
  @override
  Future<SubscriptionPlan> build() async {
    ref.watch(mockDatabaseProvider);
    ref.listen(demoSettingsProvider.select((s) => s.planStatus), (_, next) => setStatus(next));
    final repo = ref.read(subscriptionRepositoryProvider);
    final plan = await repo.plan();
    final demo = ref.read(demoSettingsProvider).planStatus;
    return plan.status == demo ? plan : repo.setStatus(demo);
  }

  SubscriptionRepository get _repo => ref.read(subscriptionRepositoryProvider);

  Future<void> setStatus(PlanStatus s) async => state = AsyncData(await _repo.setStatus(s));

  Future<void> setupAutopay(String app) async => state = AsyncData(await _repo.setupAutopay(app));

  /// Throws [PaymentFailedException] when Demo control "Fail next payment" is on.
  Future<void> payNow(String app) async {
    state = AsyncData(await _repo.payNow(app));
    ref.invalidate(paymentsProvider);
  }

  /// S-14 "Pay later": grace period.
  Future<void> payLater() => setStatus(PlanStatus.grace);

  Future<void> pause() async => state = AsyncData(await _repo.pause());
  Future<void> resume() async => state = AsyncData(await _repo.resume());
  Future<void> cancel() async => state = AsyncData(await _repo.cancel());
  Future<void> changeVehicle(VehicleKind v) async => state = AsyncData(await _repo.changePlanVehicle(v));
}

final planProvider = AsyncNotifierProvider<PlanController, SubscriptionPlan>(PlanController.new);

final paymentsProvider = FutureProvider<List<PaymentRecord>>((ref) {
  ref.watch(mockDatabaseProvider);
  return ref.watch(subscriptionRepositoryProvider).payments();
});

final driverTicketsProvider = FutureProvider<List<SupportTicket>>((ref) {
  ref.watch(mockDatabaseProvider);
  ref.watch(demoSettingsProvider.select((s) => (s.offline, s.slowLoading)));
  return ref.watch(supportRepositoryProvider).tickets();
});

/// What the driver entered during sign-up (D-03 … D-06).
@immutable
class SignupDraft {
  const SignupDraft({
    this.phone = '98430 12345',
    this.workType = WorkType.rides,
    this.vehicle = VehicleKind.bike,
    this.name = 'Karthik S',
    this.dob = '14 Mar 1994',
    this.gender = Gender.male,
    this.emergencyContact = '+91 98940 66123',
    this.upiId = 'karthik@okaxis',
    this.hasPhoto = false,
  });

  final String phone;
  final WorkType workType;
  final VehicleKind vehicle;
  final String name;
  final String dob;
  final Gender gender;
  final String emergencyContact;
  final String upiId;
  final bool hasPhoto;

  SignupDraft copyWith({
    String? phone,
    WorkType? workType,
    VehicleKind? vehicle,
    String? name,
    String? dob,
    Gender? gender,
    String? emergencyContact,
    String? upiId,
    bool? hasPhoto,
  }) =>
      SignupDraft(
        phone: phone ?? this.phone,
        workType: workType ?? this.workType,
        vehicle: vehicle ?? this.vehicle,
        name: name ?? this.name,
        dob: dob ?? this.dob,
        gender: gender ?? this.gender,
        emergencyContact: emergencyContact ?? this.emergencyContact,
        upiId: upiId ?? this.upiId,
        hasPhoto: hasPhoto ?? this.hasPhoto,
      );
}

class SignupController extends Notifier<SignupDraft> {
  @override
  SignupDraft build() => const SignupDraft();

  void update(SignupDraft Function(SignupDraft d) change) => state = change(state);

  /// D-04: also switches the demo work type so requests match (rides vs deliveries).
  void setWorkType(WorkType w) {
    final vehicle = w == WorkType.rides ? VehicleKind.bike : VehicleKind.threeWheeler;
    state = state.copyWith(workType: w, vehicle: vehicle);
    ref.read(demoSettingsProvider.notifier).update((s) => s.copyWith(workType: w));
  }

  /// D-06 Continue: writes the details to the driver profile and plan.
  Future<void> commit() async {
    final profile = ref.read(driverProfileProvider).value ?? Seed.karthik;
    final seedDriver = state.vehicle.isGoods ? Seed.selvam : Seed.karthik;
    await ref.read(driverProfileProvider.notifier).save(profile.copyWith(
          name: state.name,
          upiId: state.upiId,
          vehicleKind: state.vehicle,
          vehicleModel: state.vehicle == profile.vehicleKind ? profile.vehicleModel : seedDriver.vehicleModel,
          plate: state.vehicle == profile.vehicleKind ? profile.plate : seedDriver.plate,
          gender: state.gender,
        ));
    await ref.read(planProvider.notifier).changeVehicle(state.vehicle);
  }
}

final signupProvider = NotifierProvider<SignupController, SignupDraft>(SignupController.new);
