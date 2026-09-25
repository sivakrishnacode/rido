import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../account/p23_account_screen.dart';
import '../account/p23b_saved_place_editor_screen.dart';
import '../account/p24_emergency_contacts_screen.dart';
import '../account/p24b_add_contact_sheet.dart';
import '../account/p25_help_screen.dart';
import '../account/p25b_new_ticket_screen.dart';
import '../activity/p21_activity_screen.dart';
import '../activity/p22_trip_details_screen.dart';
import '../onboarding/p01_splash_screen.dart';
import '../onboarding/p02_onboarding_screen.dart';
import '../onboarding/p03_phone_screen.dart';
import '../onboarding/p04_otp_screen.dart';
import '../onboarding/p05_profile_setup_screen.dart';
import '../onboarding/p06_location_permission_screen.dart';
import '../parcel/pp01_parcel_home_screen.dart';
import '../parcel/pp02_pickup_details_screen.dart';
import '../parcel/pp03_drop_details_screen.dart';
import '../parcel/pp04_parcel_details_screen.dart';
import '../parcel/pp05_prohibited_items_sheet.dart';
import '../parcel/pp06_choose_goods_vehicle_screen.dart';
import '../parcel/pp07_finding_goods_driver_screen.dart';
import '../parcel/pp08_parcel_driver_assigned_screen.dart';
import '../parcel/pp09_parcel_in_transit_screen.dart';
import '../parcel/pp10_parcel_delivered_screen.dart';
import '../ride/p07_home_screen.dart';
import '../ride/p08_search_screen.dart';
import '../ride/p09_pin_on_map_screen.dart';
import '../ride/p10_choose_vehicle_screen.dart';
import '../ride/p11_fare_details_sheet.dart';
import '../ride/p12_finding_driver_screen.dart';
import '../ride/p13_driver_assigned_screen.dart';
import '../ride/p14_chat_screen.dart';
import '../ride/p15_driver_arrived_screen.dart';
import '../ride/p16_ride_in_progress_screen.dart';
import '../ride/p17_sos_screen.dart';
import '../ride/p18_share_trip_sheet.dart';
import '../ride/p19_ride_completed_screen.dart';
import '../ride/p20_rate_driver_screen.dart';
import '../states/s01_no_drivers_screen.dart';
import '../states/s02_driver_cancelled_screen.dart';
import '../states/s03_cancel_ride_dialog.dart';
import '../states/s04_no_internet_screen.dart';
import '../states/s05_location_denied_screen.dart';
import '../states/s06_empty_activity_screen.dart';
import '../states/s07_loading_skeletons.dart';
import '../states/s07b_activity_skeleton.dart';
import '../states/s08_service_unavailable_screen.dart';

/// Whether a frame can be reached in the normal app flow.
enum GalleryTag {
  inFlow('In flow'),
  showcaseOnly('Showcase only');

  const GalleryTag(this.label);
  final String label;
}

/// One designed frame from docs/design/index.md and how to render it on its own.
class GalleryEntry {
  const GalleryEntry({
    required this.id,
    required this.name,
    required this.part,
    this.tag = GalleryTag.inFlow,
    required this.builder,
  });

  final String id;
  final String name;
  final String part;
  final GalleryTag tag;
  final WidgetBuilder builder;
}

const _ds = 'Design system';
const _p2 = 'Part 2 · Sign-in and booking';
const _p3 = 'Part 3 · During and after the ride';
const _p4 = 'Part 4 · Send parcel';
const _p7 = 'Part 7 · Passenger states';

GalleryEntry _e(String id, String name, String part, WidgetBuilder builder, {GalleryTag tag = GalleryTag.inFlow}) =>
    GalleryEntry(id: id, name: name, part: part, tag: tag, builder: builder);

/// Every passenger frame in docs/design/index.md, including variants, grouped by part.
final List<GalleryEntry> galleryEntries = [
  _e('DS', 'Design system', _ds, (_) => const DesignSystemScreen(), tag: GalleryTag.showcaseOnly),
  // Part 2
  _e('P-01', 'Splash', _p2, (_) => const P01SplashScreen(showcase: true)),
  _e('P-02a', 'Onboarding · Lower fares', _p2, (_) => const P02OnboardingScreen(initialPage: 0, showcase: true)),
  _e('P-02b', 'Onboarding · Driver keeps 100%', _p2, (_) => const P02OnboardingScreen(initialPage: 1, showcase: true)),
  _e('P-02c', 'Onboarding · Rides and parcels', _p2, (_) => const P02OnboardingScreen(initialPage: 2, showcase: true)),
  _e('P-03', 'Phone number', _p2, (_) => const P03PhoneScreen(showcase: true)),
  _e('P-04', 'OTP verification', _p2, (_) => const P04OtpScreen(phone: '98765 43210', showcase: true)),
  _e('P-05', 'Profile setup', _p2, (_) => const P05ProfileSetupScreen(showcase: true)),
  _e('P-06', 'Location permission', _p2, (_) => const P06LocationPermissionScreen(showcase: true)),
  _e('P-07', 'Home · Ride tab', _p2, (_) => const P07HomeScreen(showcase: true)),
  _e('P-07b', 'Home · trip in progress banner', _p2, (_) => const P07HomeScreen(showTripBanner: true, showcase: true)),
  _e('P-08', 'Search pickup and drop', _p2, (_) => const P08SearchScreen(showcase: true)),
  _e('P-09', 'Pin on map', _p2, (_) => const P09PinOnMapScreen(showcase: true)),
  _e('P-10', 'Choose vehicle', _p2, (_) => const P10ChooseVehicleScreen(showcase: true)),
  _e('P-11', 'Fare details (sheet)', _p2,
      (_) => const ShowcaseFrame.sheet(title: 'P-11 Fare details', child: P11FareDetailsSheet(showcase: true))),
  _e('P-12', 'Finding your driver', _p2, (_) => const P12FindingDriverScreen(showcase: true)),
  // Part 3
  _e('P-13', 'Driver assigned · arriving', _p3, (_) => const P13DriverAssignedScreen(showcase: true)),
  _e('P-14', 'Chat with driver', _p3, (_) => const P14ChatScreen(showcase: true)),
  _e('P-15', 'Driver has arrived', _p3, (_) => const P15DriverArrivedScreen(showcase: true)),
  _e('P-16', 'Ride in progress', _p3, (_) => const P16RideInProgressScreen(showcase: true)),
  _e('P-17', 'SOS · Emergency help', _p3, (_) => const P17SosScreen(showcase: true)),
  _e('P-18', 'Share trip (sheet)', _p3,
      (_) => const ShowcaseFrame.sheet(title: 'P-18 Share trip', child: P18ShareTripSheet(showcase: true))),
  _e('P-19', 'Ride completed · pay driver', _p3, (_) => const P19RideCompletedScreen(showcase: true)),
  _e('P-20', 'Rate driver', _p3, (_) => const P20RateDriverScreen(showcase: true)),
  _e('P-21', 'Activity', _p3, (_) => const P21ActivityScreen(showcase: true)),
  _e('P-22', 'Trip details', _p3, (_) => const P22TripDetailsScreen(tripId: 'RD-24091528', showcase: true)),
  _e('P-23', 'Account', _p3, (_) => const P23AccountScreen(showcase: true)),
  _e('P-23b', 'Add / edit saved place', _p3, (_) => const P23bSavedPlaceEditorScreen(showcase: true)),
  _e('P-24', 'Emergency contacts', _p3, (_) => const P24EmergencyContactsScreen(showcase: true)),
  _e('P-24b', 'Add emergency contact (sheet)', _p3,
      (_) => const ShowcaseFrame.sheet(title: 'P-24b Add emergency contact', child: P24bAddContactSheet(showcase: true))),
  _e('P-25', 'Help & support', _p3, (_) => const P25HelpScreen(showcase: true)),
  _e('P-25b', 'New support ticket', _p3, (_) => const P25bNewTicketScreen(showcase: true)),
  // Part 4
  _e('PP-01', 'Parcel home', _p4, (_) => const PP01ParcelHomeScreen(showcase: true)),
  _e('PP-02', 'Pickup details', _p4, (_) => const PP02PickupDetailsScreen(showcase: true)),
  _e('PP-03', 'Drop · receiver details', _p4, (_) => const PP03DropDetailsScreen(showcase: true)),
  _e('PP-04', 'Parcel details', _p4, (_) => const PP04ParcelDetailsScreen(showcase: true)),
  _e('PP-05', 'Prohibited items (sheet)', _p4,
      (_) => const ShowcaseFrame.sheet(title: 'PP-05 Prohibited items', child: PP05ProhibitedItemsSheet(showcase: true))),
  _e('PP-06', 'Choose goods vehicle · review', _p4, (_) => const PP06ChooseGoodsVehicleScreen(showcase: true)),
  _e('PP-07', 'Finding a goods driver', _p4, (_) => const PP07FindingGoodsDriverScreen(showcase: true)),
  _e('PP-08', 'Driver assigned · picking up', _p4, (_) => const PP08ParcelDriverAssignedScreen(showcase: true)),
  _e('PP-09', 'Parcel in transit', _p4, (_) => const PP09ParcelInTransitScreen(showcase: true)),
  _e('PP-10', 'Parcel delivered', _p4, (_) => const PP10ParcelDeliveredScreen(showcase: true)),
  // Part 7
  _e('S-01', 'No drivers nearby', _p7, (_) => const S01NoDriversScreen(showcase: true)),
  _e('S-02', 'Driver cancelled', _p7, (_) => const S02DriverCancelledScreen(showcase: true)),
  _e('S-03', 'Cancel ride · confirm dialog', _p7,
      (_) => const ShowcaseFrame.dialog(title: 'S-03 Cancel ride', child: S03CancelRideDialog(showcase: true))),
  _e('S-04', 'No internet', _p7, (_) => const S04NoInternetScreen(showcase: true)),
  _e('S-05', 'Location permission denied', _p7, (_) => const S05LocationDeniedScreen(showcase: true)),
  _e('S-06', 'Empty activity', _p7, (_) => const S06EmptyActivityScreen(showcase: true)),
  _e('S-07a', 'Loading · Home sheet skeleton', _p7, (_) => const S07aHomeSkeletonScreen(showcase: true)),
  _e('S-07b', 'Loading · Activity skeleton', _p7, (_) => const S07bActivitySkeletonScreen(showcase: true)),
  _e('S-08', 'Service not available', _p7, (_) => const S08ServiceUnavailableScreen(showcase: true)),
];

/// Looks up a frame by its ID ("P-10"); null when unknown.
GalleryEntry? galleryEntryById(String id) {
  for (final e in galleryEntries) {
    if (e.id == id) return e;
  }
  return null;
}

/// The "Design system" gallery entry: the live board under an app bar.
class DesignSystemScreen extends StatelessWidget {
  const DesignSystemScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: RidoColors.background,
        appBar: RidoAppBar(title: 'Design system', subtitle: 'Rido · live board'),
        body: DesignSystemBoard(),
      );
}

/// Opens one designed frame on its own with seed data.
class GalleryFrameView extends StatelessWidget {
  const GalleryFrameView({super.key, required this.frameId});
  final String frameId;

  @override
  Widget build(BuildContext context) {
    final entry = galleryEntryById(frameId);
    if (entry == null) return _FrameNotFound(frameId: frameId);
    return entry.builder(context);
  }
}

class _FrameNotFound extends StatelessWidget {
  const _FrameNotFound({required this.frameId});
  final String frameId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const RidoAppBar(title: 'Frame not found'),
        body: EmptyState(
          illustration: const RidoIllustration(IllustrationKind.emptyTrips, width: 200, height: 160),
          title: 'Frame not found',
          message: 'There is no designed frame called "$frameId".',
          actionLabel: 'Back to gallery',
          onAction: () => context.canPop() ? context.pop() : context.go(Routes.gallery),
        ),
      );
}
