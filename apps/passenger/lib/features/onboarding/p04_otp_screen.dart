import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/live_trip.dart';
import '../../state/session_actions.dart';

/// P-04 OTP verification: 6-box input, resend countdown, Verify.
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
        // Live API: reopen a trip that is still running on the server.
        final trip = await restoreActiveTrip(ref);
        if (!mounted) return;
        context.go(trip ?? Routes.ride);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Scaffold(
      backgroundColor: RidoColors.surface,
      appBar: RidoAppBar(onBack: _edit),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.l, RidoSpacing.l, RidoSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Verify OTP', style: t.display),
                    const SizedBox(height: RidoSpacing.xs),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Sent to ', style: t.body.copyWith(color: RidoColors.navy700)),
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
                    const SizedBox(height: RidoSpacing.l),
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
                    if (_error) ...[
                      const SizedBox(height: RidoSpacing.s),
                      Row(
                        children: [
                          const Icon(Symbols.error_rounded, size: 18, color: RidoColors.error, fill: 1),
                          const SizedBox(width: 6),
                          Text(
                            'Incorrect OTP. Please try again.',
                            style: t.bodySmallMedium.copyWith(color: RidoColors.error),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: RidoSpacing.l),
                    _secondsLeft > 0
                        ? SizedBox(
                            height: 48,
                            child: Row(
                              children: [
                                const Icon(Symbols.schedule_rounded, size: 20, color: RidoColors.navy500),
                                const SizedBox(width: RidoSpacing.s),
                                Text('Resend OTP in ', style: t.body.copyWith(color: RidoColors.navy500)),
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
                            label: Text('Resend OTP', style: t.bodySemibold.copyWith(color: RidoColors.coral600)),
                          ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.s, RidoSpacing.l, RidoSpacing.l),
              child: RidoButton(label: 'Verify', loading: _verifying, onPressed: _otp.length == 6 ? _verify : null),
            ),
          ],
        ),
      ),
    );
  }
}
