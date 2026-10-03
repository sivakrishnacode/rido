import 'package:tamiltaxi_data/tamiltaxi_data.dart';

import '../router/routes.dart';

/// Where a signed-in driver lands (live API): Home once approved, otherwise always the D-07 registration page,
/// which shows what is missing, what was rejected (with the reason) or that the review is pending.
///
/// [approved]: true = approved, false = rejected, null = not decided yet.
String applicationRoute({required bool? approved}) =>
    approved == true ? Routes.home : Routes.documents;

/// Asks the API for the driver's application status and picks the start route. Offline uses the last known
/// approval: unapproved or unknown stays on Registration. On hold → Home: the account, help and trips stay reachable, and Go online
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
    final status = repo is ApiDriverRepository
        ? repo.api.session.lastDriverStatus
        : null;
    return const {'APPROVED', 'ON_HOLD'}.contains(status)
        ? Routes.home
        : Routes.documents;
  }
  return applicationRoute(approved: approved);
}
