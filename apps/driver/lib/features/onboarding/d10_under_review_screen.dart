import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/start_route.dart';
import '../../router/routes.dart';
import '../../state/driver_account.dart';
import '../../state/live_helpers.dart';
import 'widgets/signup_widgets.dart';

/// D-10 Application under review. Checks automatically after 4 s (or on "Check status"):
/// approved → D-11 Choose plan; rejected (Demo control "Reject KYC") → S-09.
/// Live API: an admin reviews the documents, so the screen checks quietly every 30 s and "Check status"
/// says so while the review is pending.
class D10UnderReviewScreen extends ConsumerStatefulWidget {
  const D10UnderReviewScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D10UnderReviewScreen> createState() => _D10UnderReviewScreenState();
}

class _D10UnderReviewScreenState extends ConsumerState<D10UnderReviewScreen> {
  Timer? _timer;
  Timer? _poll;
  bool _checking = false;
  late final bool _live = !widget.showcase && ref.read(isLiveApiProvider);

  @override
  void initState() {
    super.initState();
    if (widget.showcase) return;
    if (_live) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check(silent: true));
      _poll = Timer.periodic(const Duration(seconds: 30), (_) => _check(silent: true));
      return;
    }
    _timer = Timer(ref.read(simTimingProvider)(SimTimings.applicationReview), _check);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  /// [silent]: the live API's background check (no spinner, no "still under review" snack).
  Future<void> _check({bool silent = false}) async {
    _timer?.cancel();
    if (_checking || !mounted) return;
    if (!silent) setState(() => _checking = true);
    bool? ok;
    try {
      ok = await ref.read(kycProvider.notifier).checkApplication();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _checking = false);
      if (!silent) {
        showRidoSnack(
            context, e is OfflineException ? "You're offline. We'll check again when you're back." : userMessage(e));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _checking = false);
    if (widget.showcase) {
      showRidoSnack(context, ok == true ? 'Approved! Your documents are verified.' : 'Vehicle RC needs a clearer photo.');
      return;
    }
    if (!_live) {
      context.go(ok == true ? Routes.choosePlan : Routes.kycRejected);
      return;
    }
    if (ok == true) {
      _poll?.cancel();
      context.go(Routes.choosePlan);
      return;
    }
    final route = applicationRoute(approved: ok, docs: ref.read(kycProvider).value ?? const []);
    if (route == Routes.underReview) {
      if (!silent) {
        showRidoSnack(context, "Still under review. We'll let you know as soon as an admin approves your documents.");
      }
      return;
    }
    _poll?.cancel();
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final docs = widget.showcase ? _showcaseDocs : (ref.watch(kycProvider).value ?? _showcaseDocs);
    final phone = ref.watch(signupProvider).phone;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: RidoColors.surface,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: RidoColors.navy900,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.xl, RidoSpacing.l, RidoSpacing.xl),
                  child: Column(
                    children: [
                      Semantics(
                        image: true,
                        label: 'A clock and a document: under review',
                        child: DriverOrb(
                          size: 150,
                          color: RidoColors.coral500,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              const Icon(Symbols.schedule_rounded, size: 64, color: Colors.white, weight: 600),
                              Positioned(
                                right: -36,
                                bottom: -30,
                                child: Transform.rotate(
                                  angle: 0.1,
                                  child: Container(
                                    width: 48,
                                    height: 56,
                                    decoration: const BoxDecoration(
                                        color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(8))),
                                    child: const Icon(Symbols.description_rounded, color: RidoColors.navy900, size: 28),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: RidoSpacing.l),
                      Text("We're verifying your documents",
                          textAlign: TextAlign.center, style: t.display.copyWith(color: Colors.white)),
                      const SizedBox(height: RidoSpacing.xs),
                      Text('Usually within 24 hours', style: t.body.copyWith(color: RidoColors.navy300)),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(RidoSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l),
                      decoration: BoxDecoration(
                        color: RidoColors.surface,
                        borderRadius: RidoRadii.cardRadius,
                        border: Border.all(color: RidoColors.divider),
                      ),
                      child: Column(
                        children: [
                          for (final d in docs) ...[
                            _CheckRow(
                              label: d.type == KycDocType.policeVerification ? 'Police verification' : d.type.label,
                              status: d.status,
                            ),
                            if (!_live || d != docs.last) const Divider(height: 1),
                          ],
                          if (!_live) const _CheckRow(label: 'Selfie', status: KycStatus.underReview),
                        ],
                      ),
                    ),
                    const SizedBox(height: RidoSpacing.l),
                    Text("We'll send an SMS to +91 $phone when you're approved. You can close the app.",
                        style: t.bodySmall.copyWith(color: RidoColors.navy700)),
                  ],
                ),
              ),
            ),
            BottomActions(
              children: [
                RidoButton(
                  label: _checking ? 'Checking…' : 'Check status',
                  icon: Symbols.refresh_rounded,
                  loading: _checking,
                  onPressed: _check,
                ),
                const SizedBox(height: RidoSpacing.xs),
                Center(
                  child: RidoButton.text(
                    label: 'Contact support',
                    icon: Symbols.support_agent_rounded,
                    onPressed: () => context.push(Routes.help),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _showcaseDocs = [
  KycDocument(type: KycDocType.drivingLicence, status: KycStatus.verified),
  KycDocument(type: KycDocType.aadhaar, status: KycStatus.verified),
  KycDocument(type: KycDocType.vehicleRc, status: KycStatus.verified),
  KycDocument(type: KycDocType.insurance, status: KycStatus.underReview),
  KycDocument(type: KycDocType.policeVerification, status: KycStatus.underReview),
];

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.status});
  final String label;
  final KycStatus status;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final (IconData icon, Color c, Color fg, String text) = switch (status) {
      KycStatus.verified => (Symbols.check_circle_rounded, RidoColors.success, RidoColors.successText, 'Verified'),
      KycStatus.underReview => (Symbols.schedule_rounded, RidoColors.warning, RidoColors.warningText, 'Under review'),
      KycStatus.rejected => (Symbols.cancel_rounded, RidoColors.error, RidoColors.error, 'Rejected'),
      KycStatus.notUploaded => (Symbols.radio_button_unchecked_rounded, RidoColors.navy500, RidoColors.navy500, 'Not uploaded'),
    };
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Icon(icon, color: c, fill: 1, size: 22),
          const SizedBox(width: RidoSpacing.m),
          Expanded(child: Text(label, style: t.body, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text(text, style: t.bodySmallMedium.copyWith(color: fg)),
        ],
      ),
    );
  }
}
