import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_session.dart';
import 'widgets/job_common.dart';
import 'widgets/otp_step.dart';

/// D-17 Enter ride OTP: "Ask Priya for the 4-digit OTP". 4829 → Start ride → D-18;
/// anything else shakes and shows "Wrong OTP, please try again" (D-17-error).
class D17RideOtpScreen extends ConsumerStatefulWidget {
  const D17RideOtpScreen({super.key, this.showError = false, this.showcase = false});

  /// Show the D-17-error state.
  final bool showError;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D17RideOtpScreen> createState() => _D17RideOtpScreenState();
}

class _D17RideOtpScreenState extends ConsumerState<D17RideOtpScreen> {
  late final RideRequest _job = ref.read(driverSessionProvider).job ?? Seed.rideRequest;
  // Prefilled with the passenger's OTP for demos; the error frame shows a wrong code.
  late String _code = widget.showError ? '4826' : (_job.otp.isNotEmpty ? _job.otp : Seed.rideOtp);
  late bool _error = widget.showError;
  int _shake = 0;

  void _start() {
    final session = ref.read(driverSessionProvider.notifier);
    if (!session.verifyRideOtp(_code)) {
      setState(() {
        _error = true;
        _shake++;
      });
      return;
    }
    if (widget.showcase) {
      context.push(Routes.trip);
      return;
    }
    session.startTrip();
    context.pushReplacement(Routes.trip);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return OtpStepScaffold(
      appBarTitle: 'Start ride',
      title: 'Ask ${_job.customerName} for the 4-digit OTP',
      subtitle: 'She can see it in her Rido app.',
      otp: OtpInput(
        length: 4,
        boxSize: 80,
        autofocus: !widget.showcase && !widget.showError,
        initialValue: _code,
        hasError: _error,
        shakeTrigger: _shake,
        onChanged: (v) => setState(() {
          _code = v;
          _error = false;
        }),
      ),
      error: _error ? 'Wrong OTP, please try again' : null,
      extra: Container(
        padding: const EdgeInsets.all(RidoSpacing.l),
        decoration: const BoxDecoration(color: RidoColors.inputBg, borderRadius: RidoRadii.cardRadius),
        child: Row(children: [
          RidoAvatar(initials: initialsOf(_job.customerName), size: 40),
          const SizedBox(width: RidoSpacing.m),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_job.customerName} → ${_job.drop.name}',
                  style: t.bodySemibold, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${formatKm(_job.tripKm)} · ${formatInr(_job.fare)}',
                  style: RidoTextStyles.tabular(t.caption.copyWith(fontWeight: FontWeight.w500))),
            ]),
          ),
        ]),
      ),
      buttonLabel: 'Start ride',
      onSubmit: _code.length == 4 ? _start : null,
    );
  }
}
