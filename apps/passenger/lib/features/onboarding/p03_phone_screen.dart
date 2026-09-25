import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';

/// P-03 Phone number: +91 input, "Send OTP" (enabled at 10 digits), Terms & Privacy links.
class P03PhoneScreen extends ConsumerStatefulWidget {
  const P03PhoneScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P03PhoneScreen> createState() => _P03PhoneScreenState();
}

class _P03PhoneScreenState extends ConsumerState<P03PhoneScreen> {
  final _controller = TextEditingController(text: '98765 43210');
  late final TapGestureRecognizer _terms = TapGestureRecognizer()..onTap = () => context.push(Routes.legal('terms'));
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => context.push(Routes.legal('privacy'));
  bool _sending = false;

  String get _digits => PhoneInput.digitsOf(_controller.text);

  @override
  void dispose() {
    _controller.dispose();
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_digits.length != 10 || _sending) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    final formatted = '${_digits.substring(0, 5)} ${_digits.substring(5)}';
    try {
      await ref.read(authRepositoryProvider).sendOtp(formatted);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    if (!mounted) return;
    context.push('${Routes.otp}?phone=${Uri.encodeQueryComponent(formatted)}');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final canPop = context.canPop();
    return Scaffold(
      backgroundColor: RidoColors.surface,
      appBar: canPop ? const RidoAppBar() : null,
      body: SafeArea(
        top: !canPop,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(RidoSpacing.l, canPop ? RidoSpacing.l : 64, RidoSpacing.l, RidoSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enter your mobile number', style: t.display),
                    const SizedBox(height: RidoSpacing.s),
                    Text("We'll send you a 6-digit OTP", style: t.body.copyWith(color: RidoColors.navy700)),
                    const SizedBox(height: RidoSpacing.xxl),
                    ValueListenableBuilder(
                      valueListenable: _controller,
                      builder: (context, _, _) =>
                          PhoneInput(controller: _controller, autofocus: !widget.showcase, onSubmitted: (_) => _send()),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.s, RidoSpacing.l, RidoSpacing.l),
              child: Column(
                children: [
                  ValueListenableBuilder(
                    valueListenable: _controller,
                    builder: (context, _, _) => RidoButton(
                      label: 'Send OTP',
                      loading: _sending,
                      onPressed: _digits.length == 10 ? _send : null,
                    ),
                  ),
                  const SizedBox(height: RidoSpacing.m),
                  Text.rich(
                    TextSpan(
                      style: t.bodySmall.copyWith(color: RidoColors.navy500),
                      children: [
                        const TextSpan(text: 'By continuing, you agree to our '),
                        TextSpan(
                          text: 'Terms',
                          recognizer: _terms,
                          style: const TextStyle(color: RidoColors.coral600, fontWeight: FontWeight.w600),
                        ),
                        const TextSpan(text: ' & '),
                        TextSpan(
                          text: 'Privacy Policy',
                          recognizer: _privacy,
                          style: const TextStyle(color: RidoColors.coral600, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
