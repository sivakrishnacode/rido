import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/live_trip.dart';
import '../../state/session_actions.dart';
import 'widgets/sign_in_step.dart';

/// P-04 OTP verification (sign-in step 2/3): 6-box input, resend countdown, Verify.
/// A returning passenger gets a confetti burst before Home.
/// Any 6 digits work except 000000 ("Incorrect OTP" + shake).
class P04OtpScreen extends ConsumerStatefulWidget {
  const P04OtpScreen({super.key, this.phone = '98765 43210', this.showcase = false});

  final String phone;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P04OtpScreen> createState() => _P04OtpScreenState();
}

class _P04OtpScreenState extends ConsumerState<P04OtpScreen> {
  static const _resendAfter = 30;

  Timer? _timer;
  late int _secondsLeft = widget.showcase ? 24 : _resendAfter;
  late String _otp = widget.showcase ? '48291' : '';
  bool _verifying = false;
  bool _error = false;
  int _shake = 0;
  int _celebrate = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.showcase) _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendAfter);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, _resendAfter));
      if (_secondsLeft == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// The API wants digits only ("9876543210"); the screen shows "98765 43210".
  String get _phoneDigits => widget.phone.replaceAll(RegExp(r'\D'), '');

  Future<void> _resend() async {
    _startCountdown();
    try {
      await ref.read(authRepositoryProvider).sendOtp(_phoneDigits);
    } catch (e) {
      if (mounted) showRidoSnack(context, apiErrorMessage(e));
      return;
    }
    if (!mounted) return;
    showRidoSnack(context, 'OTP resent', success: true);
  }

  void _edit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.login);
    }
  }

  Future<void> _verify() async {
    if (_otp.length != 6 || _verifying) return;
    setState(() => _verifying = true);
    final OtpResult result;
    try {
      result = await ref.read(authRepositoryProvider).verifyOtp(_phoneDigits, _otp);
    } catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      showRidoSnack(context, apiErrorMessage(e));
      return;
    }
    if (!mounted) return;
    if (result != OtpResult.incorrect) {
      // A different account may have signed in: drop anything cached from before.
      resetSignedInState(ref);
    }
    switch (result) {
      case OtpResult.incorrect:
        setState(() {
          _verifying = false;
          _error = true;
          _shake++;
        });
      case OtpResult.newUser:
        context.go(Routes.profileSetup);
      case OtpResult.existingUser:
        // Welcome back: confetti while the active trip (live API) is looked up.
        setState(() => _celebrate++);
        final (trip, _) = await (restoreActiveTrip(ref), Future<void>.delayed(ConfettiBurst.duration * 0.7)).wait;
        if (!mounted) return;
        context.go(trip ?? Routes.ride);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return SignInStep(
      step: 2,
      badge: Symbols.sms_rounded,
      title: 'Check your messages',
      subtitle: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Code sent to '),
          Text('+91 ${widget.phone}', style: RidoTextStyles.tabular(t.bodySemibold)),
          TextButton(
            onPressed: _edit,
            style: TextButton.styleFrom(
              foregroundColor: RidoColors.coral600,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.s),
            ),
            child: Text('Edit', style: t.bodySemibold.copyWith(color: RidoColors.coral600)),
          ),
        ],
      ),
      onBack: _edit,
      overlay: ConfettiBurst(trigger: _celebrate),
      card: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OtpInput(
            initialValue: _otp,
            autofocus: !widget.showcase,
            hasError: _error,
            shakeTrigger: _shake,
            onChanged: (v) => setState(() {
              _otp = v;
              _error = false;
            }),
            onCompleted: (_) => _verify(),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _error
                ? Padding(
                    padding: const EdgeInsets.only(top: RidoSpacing.s),
                    child: Row(
                      children: [
                        const Icon(Symbols.error_rounded, size: 18, color: RidoColors.error, fill: 1),
                        const SizedBox(width: 6),
                        Text(
                          'Oops, that code didn\'t match. Try again.',
                          style: t.bodySmallMedium.copyWith(color: RidoColors.error),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: RidoSpacing.m),
          _secondsLeft > 0
              ? SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          value: _secondsLeft / _resendAfter,
                          strokeWidth: 2.5,
                          backgroundColor: RidoColors.divider,
                          color: RidoColors.coral500,
                        ),
                      ),
                      const SizedBox(width: RidoSpacing.s),
                      Text('Resend code in ', style: t.body.copyWith(color: RidoColors.navy500)),
                      Text(
                        formatCountdown(Duration(seconds: _secondsLeft)),
                        style: RidoTextStyles.tabular(t.bodySemibold),
                      ),
                    ],
                  ),
                )
              : TextButton.icon(
                  onPressed: _resend,
                  style: TextButton.styleFrom(
                    foregroundColor: RidoColors.coral600,
                    minimumSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Symbols.refresh_rounded, size: 20),
                  label: Text('Resend code', style: t.bodySemibold.copyWith(color: RidoColors.coral600)),
                ),
        ],
      ),
      action: PopWhenReady(
        ready: _otp.length == 6,
        child: RidoButton(label: 'Verify', loading: _verifying, onPressed: _otp.length == 6 ? _verify : null),
      ),
    );
  }
}
