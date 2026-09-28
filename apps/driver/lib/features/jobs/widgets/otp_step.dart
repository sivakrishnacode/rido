import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

/// Too many wrong OTPs: the API answers 429 `OTP_LOCKED` and refuses the OTP for `details.retryInSeconds`.
/// The screen keeps its button off (and the message up) until then.
mixin OtpLockout<T extends StatefulWidget> on State<T> {
  Timer? _lockTimer;

  bool get isOtpLocked => _lockTimer?.isActive ?? false;

  /// Starts the wait when [e] is the lockout; false for any other error.
  bool lockIfOtpLocked(ApiException e) {
    if (e.code != 'OTP_LOCKED') return false;
    final seconds = (e.details['retryInSeconds'] as num?)?.toInt() ?? 60;
    _lockTimer?.cancel();
    _lockTimer = Timer(Duration(seconds: seconds.clamp(1, 600)), () {
      if (mounted) setState(() {});
    });
    return true;
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }
}

/// Shared D-17 / D-22a body: navy app bar, big title, 4-box OTP with error state,
/// extra content and a bottom primary button.
class OtpStepScaffold extends StatelessWidget {
  const OtpStepScaffold({
    super.key,
    required this.appBarTitle,
    required this.title,
    required this.subtitle,
    required this.otp,
    required this.error,
    required this.extra,
    required this.buttonLabel,
    required this.onSubmit,
    this.busy = false,
  });

  final String appBarTitle;
  final String title;
  final String subtitle;
  final Widget otp;
  final String? error;
  final Widget extra;
  final String buttonLabel;
  final VoidCallback? onSubmit;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Scaffold(
      backgroundColor: RidoColors.surface,
      appBar: RidoAppBar.driver(title: appBarTitle, showBack: true),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.xxl, RidoSpacing.gutter, RidoSpacing.l),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(title, style: t.display),
                const SizedBox(height: RidoSpacing.s),
                Text(subtitle, style: t.body.copyWith(color: RidoColors.navy700)),
                const SizedBox(height: RidoSpacing.xl),
                otp,
                if (error != null) ...[
                  const SizedBox(height: RidoSpacing.m),
                  Semantics(
                    liveRegion: true,
                    child: Row(children: [
                      const Icon(Symbols.error_rounded, color: RidoColors.error, fill: 1, size: 20),
                      const SizedBox(width: RidoSpacing.s),
                      Expanded(child: Text(error!, style: t.bodySmallMedium.copyWith(color: RidoColors.error))),
                    ]),
                  ),
                ],
                const SizedBox(height: RidoSpacing.xl),
                extra,
              ]),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.s, RidoSpacing.gutter, RidoSpacing.l),
              child: RidoButton(label: buttonLabel, loading: busy, onPressed: onSubmit),
            ),
          ),
        ],
      ),
    );
  }
}
