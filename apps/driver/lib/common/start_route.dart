import 'package:tamiltaxi_data/tamiltaxi_data.dart';

import '../router/routes.dart';

/// Where a signed-in driver lands (live API): Home once approved, otherwise always the D-07 registration page,
/// which shows what is missing, what was rejected (with the reason) or that the review is pending.
///
/// [approved]: true = approved, false = rejected, null = not decided yet.
String applicationRoute({required bool? approved}) =>
    approved == true ? Routes.home : Routes.documents;

/// Asks the API for the driver's application status and picks the start route. Offline → Home
/// (it shows its own offline state). On hold → Home too: the account, help and trips stay reachable, and Go online
/// explains the hold (S-10) instead of D-07 claiming it is under review.
Future<String> driverStartRoute(DriverRepository repo, IdentityRepository identity) async {
  bool? approved;
  try {
    approved = await repo.checkApplication();
  } on StillUnderReviewException {
    approved = null;
  } on AccountOnHoldException {
    return Routes.home;
  } on OfflineException {
    return Routes.home;
  }
  return applicationRoute(approved: approved);
}
