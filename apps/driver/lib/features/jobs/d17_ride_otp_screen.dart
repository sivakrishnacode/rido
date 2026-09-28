import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_session.dart';
import '../../state/live_helpers.dart';
import 'widgets/job_common.dart';
import 'widgets/otp_step.dart';

/// D-17 Enter ride OTP: "Ask Priya for the 4-digit OTP". 4829 → Start ride → D-18;
/// anything else shakes and shows "Wrong OTP, please try again" (D-17-error).
/// Live API: the server checks the code when the ride starts and its message shows as the error.
class D17RideOtpScreen extends ConsumerStatefulWidget {
  const D17RideOtpScreen({super.key, this.showError = false, this.showcase = false});

  /// Show the D-17-error state.
  final bool showError;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D17RideOtpScreen> createState() => _D17RideOtpScreenState();
}

class _D17RideOtpScreenState extends ConsumerState<D17RideOtpScreen>
    with OtpLockout<D17RideOtpScreen> {
  late final RideRequest _job = ref.read(driverSessionProvider).job ?? Seed.rideRequest;
  late final bool _api = !widget.showcase && ref.read(isLiveApiProvider);
  // Prefilled with the passenger's OTP for demos; the error frame shows a wrong code. The live app
  // never knows the OTP: the passenger reads it out.
  late String _code = widget.showError ? '4826' : (_api ? '' : (_job.otp.isNotEmpty ? _job.otp : Seed.rideOtp));
  late String? _errorText = widget.showError ? _wrongOtp : null;
  int _shake = 0;
  bool _busy = false;

  static const _wrongOtp = 'Wrong OTP, please try again';

  void _fail(String message) => setState(() {
        _busy = false;
        _errorText = message;
        _shake++;
      });

  Future<void> _start() async {
    if (_busy) return;
    final session = ref.read(driverSessionProvider.notifier);
    if (_api) {
      setState(() => _busy = true);
      try {
        await session.startTrip(otp: _code);
      } on ApiException catch (e) {
        if (!mounted) return;
        lockIfOtpLocked(e);
        _fail(e.message);
        return;
      } on Exception catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        showRidoSnack(context, userMessage(e));
        return;
      }
      if (mounted) context.pushReplacement(Routes.trip);
      return;
    }
    if (!session.verifyRideOtp(_code)) {
      _fail(_wrongOtp);
      return;
    }
    if (widget.showcase) {
      context.push(Routes.trip);
      return;
    }
    await session.startTrip();
    if (mounted) context.pushReplacement(Routes.trip);
  }

  Future<void> _cancelNotWoman() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => RidoDialog(
        title: 'Cancel this Butterfly ride?',
        message: "This ride is for women only. If the rider isn't a woman you can cancel. It won't count against you.",
        icon: Symbols.cancel_rounded,
        destructive: true,
        actions: [
          RidoButton.danger(label: 'Cancel ride', onPressed: () => Navigator.of(context).pop(true)),
          const SizedBox(height: RidoSpacing.xs),
          RidoButton.text(label: 'Keep ride', expand: true, onPressed: () => Navigator.of(context).pop(false)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(driverSessionProvider.notifier).cancelJob(reason: kRiderNotWoman);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showRidoSnack(context, userMessage(e));
      return;
    }
    if (!mounted) return;
    showRidoSnack(context, 'Ride cancelled · $kRiderNotWoman');
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return OtpStepScaffold(
      appBarTitle: 'Start ride',
      title: 'Ask ${_job.customerName} for the 4-digit OTP',
      subtitle: _job.bookedBy != null
          ? '${_job.bookedBy} booked this ride and has the OTP in their Rido app.'
          : 'It is in their Rido app.',
      otp: OtpInput(
        length: 4,
        boxSize: 80,
        autofocus: !widget.showcase && !widget.showError,
        initialValue: _code,
        hasError: _errorText != null,
        shakeTrigger: _shake,
        onChanged: (v) => setState(() {
          _code = v;
          if (!isOtpLocked) _errorText = null;
        }),
      ),
      error: _errorText,
      extra: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
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
        // Butterfly (women only): the driver may cancel, with no penalty, if the rider is not a woman.
        if (_job.isWomenOnly && !widget.showcase) ...[
          const SizedBox(height: RidoSpacing.s),
          RidoButton.text(label: "Rider isn't a woman? Cancel ride", onPressed: _busy ? null : _cancelNotWoman),
        ],
      ]),
      buttonLabel: 'Start ride',
      busy: _busy,
      onSubmit: _code.length == 4 && !isOtpLocked ? _start : null,
    );
  }
}
