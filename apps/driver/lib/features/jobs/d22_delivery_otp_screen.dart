import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_session.dart';
import 'widgets/otp_step.dart';

/// D-22a Complete delivery: "Ask Meena for the delivery OTP" (7153), optional photo of the
/// delivered parcel, "Complete delivery" → D-22b collect. Wrong code shakes with an error.
class D22DeliveryOtpScreen extends ConsumerStatefulWidget {
  const D22DeliveryOtpScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D22DeliveryOtpScreen> createState() => _D22DeliveryOtpScreenState();
}

class _D22DeliveryOtpScreenState extends ConsumerState<D22DeliveryOtpScreen> {
  late final RideRequest _job = ref.read(driverSessionProvider).job ?? Seed.deliveryRequest;
  late String _code = widget.showcase ? Seed.deliveryOtp : '';
  bool _error = false;
  bool _photo = false;
  int _shake = 0;

  void _complete() {
    final c = ref.read(driverSessionProvider.notifier);
    if (!c.verifyDeliveryOtp(_code)) {
      setState(() {
        _error = true;
        _shake++;
      });
      return;
    }
    if (widget.showcase) {
      context.push(Routes.collectDelivery);
      return;
    }
    c.completeDelivery();
    context.pushReplacement(Routes.collectDelivery);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final receiver = _job.parcel?.receiverName ?? _job.customerName;
    final phone = _job.parcel?.receiverPhone ?? _job.customerPhone;
    return OtpStepScaffold(
      appBarTitle: 'Complete delivery',
      title: 'Ask ${receiver.split(' ').first} for the delivery OTP',
      subtitle: 'It was sent to $phone by SMS.',
      otp: OtpInput(
        length: 4,
        boxSize: 80,
        autofocus: !widget.showcase,
        initialValue: _code,
        hasError: _error,
        shakeTrigger: _shake,
        onChanged: (v) => setState(() {
          _code = v;
          _error = false;
        }),
      ),
      error: _error ? 'Wrong OTP, please try again' : null,
      extra: Material(
        color: _photo ? RidoColors.successTint : RidoColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: RidoRadii.cardRadius,
          side: BorderSide(color: _photo ? RidoColors.success : RidoColors.navy300),
        ),
        child: InkWell(
          borderRadius: RidoRadii.cardRadius,
          onTap: () {
            setState(() => _photo = !_photo);
            showRidoSnack(context, _photo ? 'Photo of delivered parcel added' : 'Photo removed');
          },
          child: Padding(
            padding: const EdgeInsets.all(RidoSpacing.l),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: RidoColors.surface,
                  borderRadius: RidoRadii.cardRadius,
                  border: Border.all(color: RidoColors.divider),
                ),
                child: Icon(_photo ? Symbols.check_circle_rounded : Symbols.add_a_photo_rounded,
                    color: _photo ? RidoColors.success : RidoColors.coral600, fill: _photo ? 1 : 0),
              ),
              const SizedBox(width: RidoSpacing.l),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_photo ? 'Photo added' : 'Take photo of delivered parcel', style: t.bodySemibold),
                  Text(_photo ? 'Tap to remove' : 'Optional · protects you in disputes', style: t.caption),
                ]),
              ),
            ]),
          ),
        ),
      ),
      buttonLabel: 'Complete delivery',
      onSubmit: _code.length == 4 ? _complete : null,
    );
  }
}
