import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import 'features/ride/p18_share_trip_sheet.dart';
import 'features/ride/safety_check_sheet.dart';
import 'router/app_router.dart';
import 'router/routes.dart';
import 'state/app_notice.dart';
import 'state/session_actions.dart';
import 'state/trip_safety.dart';

/// The passenger app root. [router] is injectable for tests.
class TtPassengerApp extends ConsumerStatefulWidget {
  const TtPassengerApp({super.key, this.router});
  final GoRouter? router;

  @override
  ConsumerState<TtPassengerApp> createState() => _TtPassengerAppState();
}

class _TtPassengerAppState extends ConsumerState<TtPassengerApp> {
  late final GoRouter _router = widget.router ?? createPassengerRouter();
  StreamSubscription<void>? _unauthorized;
  StreamSubscription<PushData>? _pushTaps;
  StreamSubscription<SafetyCheck>? _safetyChecks;

  /// Safety checks already shown (the socket event and the push tap are the same check), and one at a time.
  final _shownChecks = <String>{};
  bool _isShowingCheck = false;

  @override
  void initState() {
    super.initState();
    // Live API: a rejected token (expired, or the account was blocked) sends the passenger to sign in.
    if (ref.read(isLiveApiProvider)) {
      _unauthorized = ref.read(apiClientProvider).onUnauthorized.listen((_) {
        if (!mounted) return;
        resetSignedInState(ref);
        ref.read(appNoticeProvider.notifier).show('Please sign in again', goTo: Routes.login);
      });
      // "Is everything OK?" while the app is open (socket), over whatever screen is up.
      _safetyChecks = ref.read(liveSafetyProvider).checks().listen((c) => _showSafetyCheck(c, openTrip: false));
      final push = ref.read(pushProvider);
      if (push != null) {
        // Trip progress is already on screen while the app is open; chat and announcements still show.
        push.suppress = (data) => data['type'] == 'trip';
        _pushTaps = push.taps.listen(_onPushTap);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final launch = push.takeLaunchTap();
          if (launch != null) _onPushTap(launch);
        });
      }
    }
  }

  /// A tapped notification about a trip or its chat opens that trip's screen; a safety check opens its sheet.
  Future<void> _onPushTap(PushData data) async {
    if (data['type'] == 'safety') {
      final check = SafetyCheck.fromJson(data);
      return _showSafetyCheck(check, openTrip: !check.isArrival);
    }
    if (data['type'] != 'trip' && data['type'] != 'chat') return;
    final route = await restoreActiveTrip(ref);
    if (mounted && route != null) _router.go(route);
  }

  /// The I'm OK / Get help sheet for [check] (once per check); "Get help" opens the SOS screen. A night-start
  /// reminder opens the share sheet instead. [openTrip]: go to the ride first (a tapped push while the app was
  /// elsewhere).
  Future<void> _showSafetyCheck(SafetyCheck check, {required bool openTrip}) async {
    final key = check.eventId ?? '${check.tripId}:${check.kind}';
    if (_isShowingCheck || _shownChecks.contains(key)) return;
    _isShowingCheck = true;
    _shownChecks.add(key);
    try {
      if (openTrip) {
        final route = await restoreActiveTrip(ref);
        if (mounted && route != null) _router.go(route);
        await WidgetsBinding.instance.endOfFrame;
      }
      final context = rootNavigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      // Night ride start: "Share your trip with a friend?" opens the share sheet (once per trip).
      if (check.isShareReminder) {
        if (ref.read(autoSharePromptedProvider.notifier).claim(check.tripId)) await P18ShareTripSheet.show(context);
        return;
      }
      final answer = await SafetyCheckSheet.show(context, check);
      if (answer == SafetyAnswer.help && mounted) unawaited(_router.push(Routes.sos));
    } finally {
      _isShowingCheck = false;
    }
  }

  @override
  void dispose() {
    _safetyChecks?.cancel();
    _unauthorized?.cancel();
    _pushTaps?.cancel();
    super.dispose();
  }

  void _showNotice(AppNotice notice) {
    final goTo = notice.goTo;
    if (goTo != null) _router.go(goTo);
    final context = rootNavigatorKey.currentContext;
    if (context != null) showTtSnack(context, notice.message);
  }

  @override
  Widget build(BuildContext context) {
    // Messages from controllers (e.g. the server cancelled the trip), shown wherever the passenger is.
    ref.listen(appNoticeProvider, (_, next) {
      if (next != null) _showNotice(next);
    });
    return MaterialApp.router(
      title: 'Tamil Taxi',
      debugShowCheckedModeBanner: false,
      theme: TtTheme.light(),
      themeMode: ThemeMode.light,
      routerConfig: _router,
    );
  }
}
