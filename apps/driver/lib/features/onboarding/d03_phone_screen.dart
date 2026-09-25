import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_account.dart';
import 'widgets/signup_widgets.dart';

/// D-03a Phone number: +91 input; "Send OTP" (enabled at 10 digits) → D-03b.
class D03PhoneScreen extends ConsumerStatefulWidget {
  const D03PhoneScreen({super.key, this.signup = true, this.showcase = false});

  final bool signup;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D03PhoneScreen> createState() => _D03PhoneScreenState();
}

class _D03PhoneScreenState extends ConsumerState<D03PhoneScreen> {
  late final TextEditingController _phone = TextEditingController(text: widget.showcase ? '98940 56721' : '');
  bool _sending = false;

  String get _digits => PhoneInput.digitsOf(_phone.text);

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_digits.length != 10 || _sending) return;
    final formatted = '${_digits.substring(0, 5)} ${_digits.substring(5)}';
    setState(() => _sending = true);
    try {
      await ref.read(driverRepositoryProvider).sendOtp(formatted);
    } on OfflineException {
      if (!mounted) return;
      setState(() => _sending = false);
      showRidoSnack(context, "You're offline. Check your connection and try again.");
      return;
    }
    if (!mounted) return;
    setState(() => _sending = false);
    if (widget.signup) {
      ref.read(signupProvider.notifier).update((d) => d.copyWith(phone: formatted));
    }
    context.push(Routes.otp(phone: formatted, signup: widget.signup));
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
            title: widget.signup ? 'Enter your mobile number' : 'Welcome back',
            subtitle: Text(
              widget.signup ? "We'll send you a 6-digit OTP" : "Log in with your registered number. We'll send a 6-digit OTP",
              style: t.body.copyWith(color: RidoColors.navy300),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.xl, RidoSpacing.l, RidoSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PhoneInput(
                    controller: _phone,
                    autofocus: !widget.showcase,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _send(),
                  ),
                  const SizedBox(height: RidoSpacing.s),
                  Text('Use the number linked to your UPI for faster payouts',
                      style: t.caption.copyWith(color: RidoColors.navy500)),
                ],
              ),
            ),
          ),
          BottomActions(
            children: [
              RidoButton(
                label: 'Send OTP',
                loading: _sending,
                onPressed: _digits.length == 10 ? _send : null,
              ),
              const SizedBox(height: RidoSpacing.xs),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('By continuing, you agree to the ', style: t.caption.copyWith(color: RidoColors.navy500)),
                  _Link(label: 'Driver Terms', onTap: () => context.push(Routes.legal('terms'))),
                  Text(' & ', style: t.caption.copyWith(color: RidoColors.navy500)),
                  _Link(label: 'Privacy Policy', onTap: () => context.push(Routes.legal('privacy'))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        link: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              widthFactor: 1,
              child: Text(label,
                  style: context.type.caption.copyWith(color: RidoColors.coral600, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      );
}
