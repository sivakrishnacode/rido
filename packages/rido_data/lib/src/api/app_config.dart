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
  const AppConfig({required this.driverPlansEnabled, required this.supportPhone, required this.contribute});

  /// Off = the app is free: drivers see no plans and can always go online.
  final bool driverPlansEnabled;
  final String supportPhone;
  final ContributeInfo contribute;

  static const defaultNote = 'Rido is free for drivers and riders: 0% commission and no subscription. '
      'Contributions pay for the servers, maps and SMS that keep it running.';

  /// Used before the API answers, when it can't be reached, and in mock mode (with sample figures).
  static const fallback = AppConfig(
    driverPlansEnabled: false,
    supportPhone: '+91 422 000 0000',
    contribute: ContributeInfo(upiId: '', payeeName: 'Rido', note: defaultNote),
  );

  static const demo = AppConfig(
    driverPlansEnabled: false,
    supportPhone: '+91 422 000 0000',
    contribute: ContributeInfo(
      upiId: 'rido@okaxis',
      payeeName: 'Rido',
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
    return AppConfig(
      driverPlansEnabled: j['driverPlansEnabled'] == true,
      supportPhone: '${j['supportPhone'] ?? fallback.supportPhone}',
      contribute: ContributeInfo(
        upiId: '${c['upiId'] ?? ''}'.trim(),
        payeeName: name.isEmpty ? 'Rido' : name,
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

/// Live API: `GET /app-config` (falls back to [AppConfig.fallback] when unreachable). Mock: [AppConfig.demo].
final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  if (!ref.watch(isLiveApiProvider)) return AppConfig.demo;
  try {
    final json = await ref.watch(apiClientProvider).get('/app-config');
    return AppConfig.fromJson((json as Map).cast<String, dynamic>());
  } catch (e) {
    debugPrint('App config unavailable: $e');
    return AppConfig.fallback;
  }
});

/// Paid driver plans on? False until the config loads, so plan screens never flash for a free app.
final driverPlansEnabledProvider = Provider<bool>((ref) => ref.watch(appConfigProvider).value?.driverPlansEnabled ?? false);
