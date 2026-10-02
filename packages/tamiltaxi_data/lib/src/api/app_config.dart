import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// One line of the monthly running cost ("Maps ₹3,200").
@immutable
class CostItem {
  const CostItem(this.label, this.amountInr);
  final String label;
  final int amountInr;
}

/// The Contribute page: where contributions go and what the app costs to run each month.
@immutable
class ContributeInfo {
  const ContributeInfo({
    required this.upiId,
    required this.payeeName,
    required this.note,
    this.monthlyCostInr,
    this.costItems = const [],
  });

  /// Empty = no pay button or QR code.
  final String upiId;
  final String payeeName;
  final String note;

  /// Null while no cost is entered in the admin panel.
  final int? monthlyCostInr;
  final List<CostItem> costItems;

  bool get canPay => upiId.isNotEmpty;

  /// `upi://pay` link for GPay / PhonePe / Paytm / BHIM, with [amountInr] prefilled when given.
  /// Encoded by hand: `Uri(queryParameters:)` writes spaces as "+", which some UPI apps show literally.
  Uri payUri({int? amountInr}) {
    // The UPI ID goes in as it is ("name@bank"), like the collect-payment QR.
    final params = {
      'pn': payeeName,
      if (amountInr != null) 'am': '$amountInr',
      'cu': 'INR',
      'tn': 'Contribution to $payeeName',
    };
    return Uri.parse('upi://pay?pa=$upiId&${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}');
  }
}

/// `GET /v1/app-config`: public settings both apps read at start-up.
@immutable
class AppConfig {
  const AppConfig({
    required this.driverPlansEnabled,
    required this.supportPhone,
    required this.contribute,
    this.scheduledDispatchLeadMin = defaultDispatchLeadMin,
  });

  /// Off = the app is free: drivers see no plans and can always go online.
  final bool driverPlansEnabled;

  /// The support line (calls and WhatsApp). Empty when none is set up: the apps then offer no call.
  final String supportPhone;
  final ContributeInfo contribute;

  /// Minutes before its pickup time that a trip booked for later starts looking for a driver.
  final int scheduledDispatchLeadMin;

  /// The API's default lead, for servers that don't send it.
  static const defaultDispatchLeadMin = 30;

  /// A real support number is set up (not empty).
  bool get hasSupportPhone => supportPhone.replaceAll(RegExp(r'[^0-9]'), '').length >= 8;

  static const defaultNote = 'Tamil Taxi is free for drivers and riders: 0% commission and no subscription. '
      'Contributions pay for the servers, maps and SMS that keep it running.';

  /// Used before the API answers and while it can't be reached: no support number (none is made up).
  static const fallback = AppConfig(
    driverPlansEnabled: false,
    supportPhone: '',
    contribute: ContributeInfo(upiId: '', payeeName: 'Tamil Taxi', note: defaultNote),
  );

  /// Mock mode (seed data, Design gallery): sample figures.
  static const demo = AppConfig(
    driverPlansEnabled: false,
    supportPhone: '+91 422 000 0000',
    contribute: ContributeInfo(
      upiId: 'tamiltaxi@okaxis',
      payeeName: 'Tamil Taxi',
      note: defaultNote,
      monthlyCostInr: 6500,
      costItems: [CostItem('Servers & database', 2500), CostItem('Maps', 3000), CostItem('SMS (OTP)', 500), CostItem('Other', 500)],
    ),
  );

  factory AppConfig.fromJson(Map<String, dynamic> j) {
    final c = (j['contribute'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cost = (c['monthlyCost'] as Map?)?.cast<String, dynamic>();
    final name = '${c['payeeName'] ?? ''}'.trim();
    final note = '${c['note'] ?? ''}'.trim();
    final lead = j['scheduledDispatchLeadMin'];
    return AppConfig(
      driverPlansEnabled: j['driverPlansEnabled'] == true,
      supportPhone: j['supportPhone'] is String ? (j['supportPhone'] as String).trim() : fallback.supportPhone,
      scheduledDispatchLeadMin: lead is num && lead >= 0 ? lead.round() : defaultDispatchLeadMin,
      contribute: ContributeInfo(
        upiId: '${c['upiId'] ?? ''}'.trim(),
        payeeName: name.isEmpty ? 'Tamil Taxi' : name,
        note: note.isEmpty ? defaultNote : note,
        monthlyCostInr: (cost?['totalInr'] as num?)?.round(),
        costItems: [
          for (final i in (cost?['items'] as List? ?? const []))
            CostItem('${(i as Map)['label']}', ((i['amountInr'] as num?) ?? 0).round()),
        ],
      ),
    );
  }
}

/// `GET /app-config` itself. A failure is not kept: it is fetched again with [backgroundRetry].
final _appConfigFetchProvider = FutureProvider<AppConfig>((ref) async {
  final json = await ref.watch(apiClientProvider).get('/app-config');
  return AppConfig.fromJson((json as Map).cast<String, dynamic>());
}, retry: backgroundRetry);

/// Live API: `GET /app-config`, [AppConfig.fallback] while it can't be reached (the next successful fetch replaces it).
/// Mock: [AppConfig.demo].
final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  if (!ref.watch(isLiveApiProvider)) return AppConfig.demo;
  final fetched = ref.watch(_appConfigFetchProvider);
  if (fetched case AsyncData(:final value)) return value;
  if (fetched.hasError) {
    // Failing (and being fetched again in the background): the fallback until a fetch works.
    debugPrint('App config unavailable: ${fetched.error}');
    return AppConfig.fallback;
  }
  return ref.watch(_appConfigFetchProvider.future);
});

/// Minutes before its time that a trip booked for later starts finding a driver (the API's, else 30).
final dispatchLeadMinProvider = Provider<int>(
  (ref) => ref.watch(appConfigProvider).value?.scheduledDispatchLeadMin ?? AppConfig.defaultDispatchLeadMin,
);

/// Paid driver plans on? False until the config loads, so plan screens never flash for a free app.
final driverPlansEnabledProvider = Provider<bool>((ref) => ref.watch(appConfigProvider).value?.driverPlansEnabled ?? false);
