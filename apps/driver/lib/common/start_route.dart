import 'package:tamiltaxi_data/tamiltaxi_data.dart';

import '../router/routes.dart';

/// Where a signed-in driver lands (live API): Home once approved, otherwise always the D-07 registration page,
/// which shows what is missing, what was rejected (with the reason) or that the review is pending.
///
/// [approved]: true = approved, false = rejected, null = not decided yet.
String applicationRoute({required bool? approved}) =>
    approved == true ? Routes.home : Routes.documents;

/// Asks the API for the driver's application status and picks the start route. Offline → Home
/// (it shows its own offline state).
Future<String> driverStartRoute(DriverRepository repo, IdentityRepository identity) async {
  bool? approved;
  try {
    approved = await repo.checkApplication();
  } on StillUnderReviewException {
    approved = null;
  } on OfflineException {
    return Routes.home;
  }
  return applicationRoute(approved: approved);
}
