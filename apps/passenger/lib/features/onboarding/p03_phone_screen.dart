import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/live_trip.dart';
import 'widgets/sign_in_step.dart';

/// P-03 Phone number (sign-in step 1/3): +91 input, "Send OTP" (enabled at 10 digits), Terms & Privacy links.
class P03PhoneScreen extends ConsumerStatefulWidget {
  const P03PhoneScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P03PhoneScreen> createState() => _P03PhoneScreenState();
}

class _P03PhoneScreenState extends ConsumerState<P03PhoneScreen> {
  /// Mock mode pre-fills the demo number; with the live API the passenger types their own.
  late final _controller = TextEditingController(text: ref.read(isLiveApiProvider) ? '' : '98765 43210');
  bool _sending = false;

  String get _digits => PhoneInput.digitsOf(_controller.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_digits.length != 10 || _sending) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    final formatted = '${_digits.substring(0, 5)} ${_digits.substring(5)}';
    try {
      // The API takes digits only; the OTP screen shows the formatted number.
      await ref.read(authRepositoryProvider).sendOtp(_digits);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        showRidoSnack(context, apiErrorMessage(e));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _sending = false);
    context.push('${Routes.otp}?phone=${Uri.encodeQueryComponent(formatted)}');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _controller,
      builder: (context, _, _) {
        final ready = _digits.length == 10;
        return SignInStep(
          step: 1,
          badge: Symbols.smartphone_rounded,
          badgeMotion: BadgeMotion.buzz,
          title: 'Hi there! What\'s your number?',
          subtitle: const Text("We'll text you a 6-digit code to sign in. No passwords."),
          onBack: context.canPop() ? () => context.pop() : null,
          card: Stack(
            alignment: Alignment.centerRight,
            children: [
              PhoneInput(controller: _controller, autofocus: !widget.showcase, onSubmitted: (_) => _send()),
              // A green tick pops in at the end of the field once all 10 digits are in.
              Positioned(
                right: RidoSpacing.m,
                bottom: 14,
                child: AnimatedScale(
                  scale: ready ? 1 : 0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.elasticOut,
                  child: const Icon(Symbols.check_circle_rounded, fill: 1, color: RidoColors.success),
                ),
              ),
            ],
          ),
          footer: const SignInTerms(),
          action: PopWhenReady(
            ready: ready,
            child: RidoButton(label: 'Send OTP', loading: _sending, onPressed: ready ? _send : null),
          ),
        );
      },
    );
  }
}
