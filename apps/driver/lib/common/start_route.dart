import 'package:rido_data/rido_data.dart';

import '../router/routes.dart';

/// Where a signed-in driver lands (live API), from the admin's decision, the documents and the identity check.
///
/// [approved]: true = approved, false = rejected, null = not decided yet. A rejected driver who has
/// re-uploaded the rejected document waits on D-10 until an admin reviews it again. An identity check that
/// isn't done (or was declined) goes back to D-07, which runs it in the app.
String applicationRoute({required bool? approved, required List<KycDocument> docs, IdentityCheck? identity}) {
  if (approved == true) return Routes.home;
  if (docs.any((d) => d.status == KycStatus.rejected)) return Routes.kycRejected;
  if (docs.any((d) => d.status == KycStatus.notUploaded)) return Routes.documents;
  if (identity != null && identity.canStart) return Routes.documents;
  return Routes.underReview;
}

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
  if (approved == true) return Routes.home;
  try {
    return applicationRoute(approved: approved, docs: await repo.kycDocuments(), identity: await identity.status());
  } on OfflineException {
    return Routes.underReview;
  }
}
