import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/start_route.dart';
import '../../router/routes.dart';
import '../../state/driver_account.dart';
import '../../state/live_helpers.dart';
import 'widgets/signup_widgets.dart';

/// D-03b OTP verification: 6 boxes, a 30 s resend countdown and "Verify".
/// 000000 → "Incorrect OTP" + shake. Sign-up → D-04; log-in → Home as Karthik.
/// Live API: a phone that is already a driver goes where the application stands (Home, D-07, D-10 or
/// S-09) from either entry; a new phone continues to sign-up (D-04).
class D03bOtpScreen extends ConsumerStatefulWidget {
  const D03bOtpScreen({super.key, this.phone = '98430 12345', this.signup = true, this.showcase = false});

  final String phone;
  final bool signup;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D03bOtpScreen> createState() => _D03bOtpScreenState();
}

class _D03bOtpScreenState extends ConsumerState<D03bOtpScreen> {
  static const _resendAfter = 30;

  Timer? _timer;
  late int _secondsLeft = widget.showcase ? 24 : _resendAfter;
  late String _code = widget.showcase ? '6103' : '';
  bool _error = false;
  int _shake = 0;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    if (!widget.showcase) _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendAfter);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, _resendAfter));
      if (_secondsLeft == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _live => ref.read(isLiveApiProvider);
  String get _apiPhone => _live ? apiPhone(widget.phone) : widget.phone;

  Future<void> _resend() async {
    _startCountdown();
    try {
      await ref.read(driverRepositoryProvider).sendOtp(_apiPhone);
      if (mounted) showRidoSnack(context, 'OTP resent');
    } on Exception catch (e) {
      if (mounted) showRidoSnack(context, userMessage(e));
    }
  }

  Future<void> _verify() async {
    if (_code.length != 6 || _verifying) return;
    setState(() => _verifying = true);
    OtpResult result;
    try {
      result = await ref.read(driverRepositoryProvider).verifyOtp(_apiPhone, _code);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      showRidoSnack(context, userMessage(e));
      return;
    }
    if (!mounted) return;
    if (result == OtpResult.incorrect) {
      setState(() {
        _verifying = false;
        _error = true;
        _shake++;
      });
      return;
    }
    if (!_live) {
      setState(() => _verifying = false);
      context.go(widget.signup ? Routes.workType : Routes.home);
      return;
    }
    resetDriverData(ref);
    if (result == OtpResult.newUser) {
      ref.read(signupProvider.notifier).update((d) => d.copyWith(phone: widget.phone));
      setState(() => _verifying = false);
      if (!widget.signup) showRidoSnack(context, "This number isn't registered yet. Let's sign you up.");
      context.go(Routes.workType);
      return;
    }
    String route;
    try {
      route = await driverStartRoute(ref.read(driverRepositoryProvider));
    } on Exception {
      route = Routes.home;
    }
    if (!mounted) return;
    setState(() => _verifying = false);
    if (widget.signup) showRidoSnack(context, 'Welcome back! You already have a Rido Driver account.');
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Scaffold(
      backgroundColor: RidoColors.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeader(
            title: 'Verify OTP',
            subtitle: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Sent to ', style: t.body.copyWith(color: RidoColors.navy300)),
                Text('+91 ${widget.phone}', style: RidoTextStyles.tabular(t.bodySemibold.copyWith(color: Colors.white))),
                Text(' · ', style: t.body.copyWith(color: RidoColors.navy300)),
                Semantics(
                  button: true,
                  label: 'Edit number',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                      child: Center(
                        widthFactor: 1,
                        child: Text('Edit', style: t.bodySemibold.copyWith(color: RidoColors.coral100)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.xl, RidoSpacing.l, RidoSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OtpInput(
                    length: 6,
                    initialValue: _code,
                    hasError: _error,
                    shakeTrigger: _shake,
                    autofocus: !widget.showcase,
                    onChanged: (v) => setState(() {
                      _code = v;
                      _error = false;
                    }),
                    onCompleted: (v) {
                      _code = v;
                      _verify();
                    },
                  ),
                  if (_error) ...[
                    const SizedBox(height: RidoSpacing.s),
                    Row(
                      children: [
                        const Icon(Symbols.error_rounded, size: 18, color: RidoColors.error, fill: 1),
                        const SizedBox(width: 6),
                        Text('Incorrect OTP. Please try again.',
                            style: t.bodySmallMedium.copyWith(color: RidoColors.error)),
                      ],
                    ),
                  ],
                  const SizedBox(height: RidoSpacing.m),
                  if (_secondsLeft > 0)
                    SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          const Icon(Symbols.schedule_rounded, size: 20, color: RidoColors.navy500),
                          const SizedBox(width: RidoSpacing.s),
                          Text('Resend OTP in ', style: t.bodySmall.copyWith(color: RidoColors.navy500)),
                          Text(formatCountdown(Duration(seconds: _secondsLeft)),
                              style: RidoTextStyles.tabular(t.bodySmallMedium.copyWith(
                                  color: RidoColors.navy900, fontWeight: FontWeight.w700))),
                        ],
                      ),
                    )
                  else
                    RidoButton.text(label: 'Resend OTP', icon: Symbols.refresh_rounded, onPressed: _resend),
                ],
              ),
            ),
          ),
          BottomActions(
            children: [
              RidoButton(
                label: 'Verify',
                loading: _verifying,
                onPressed: _code.length == 6 ? _verify : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
