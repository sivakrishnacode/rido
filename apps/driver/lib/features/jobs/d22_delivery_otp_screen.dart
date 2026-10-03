import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../common/showcase.dart';
import '../../router/routes.dart';
import '../../state/driver_session.dart';
import '../../state/live_helpers.dart';
import 'widgets/otp_step.dart';
import 'widgets/too_far_sheet.dart';

/// D-22a Complete delivery: "Ask Meena for the delivery OTP" (7153), optional photo of the
/// delivered parcel, "Complete delivery" → D-22b collect. Wrong code shakes with an error.
/// Live API: the server checks the receiver's code when the delivery completes.
class D22DeliveryOtpScreen extends ConsumerStatefulWidget {
  const D22DeliveryOtpScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D22DeliveryOtpScreen> createState() =>
      _D22DeliveryOtpScreenState();
}

class _D22DeliveryOtpScreenState extends ConsumerState<D22DeliveryOtpScreen>
    with OtpLockout<D22DeliveryOtpScreen> {
  late final RideRequest _job =
      ref.read(driverSessionProvider).job ?? Seed.deliveryRequest;
  late String _code = widget.showcase ? Seed.deliveryOtp : '';
  late final bool _api = !widget.showcase && ref.read(isLiveApiProvider);
  String? _errorText;
  PhotoAttachment? _photo;
  int _shake = 0;
  bool _busy = false;

  Future<void> _uploadPhoto(PhotoAttachment photo) async {
    final api = ref.read(apiClientProvider);
    try {
      await api.upload(
        '/trips/${_job.id}/delivery-photo',
        field: 'file',
        bytes: photo.bytes,
        filename: photo.name,
      );
    } catch (_) {
      if (mounted) {
        showTtSnack(
          context,
          'Photo could not upload. You can still complete delivery.',
          actionLabel: 'Retry',
          onAction: () => _uploadPhoto(photo),
        );
      }
    }
  }

  void _fail(String message) => setState(() {
    _busy = false;
    _errorText = message;
    _shake++;
  });

  Future<void> _complete() async {
    if (_busy) return;
    final c = ref.read(driverSessionProvider.notifier);
    if (_api) {
      setState(() => _busy = true);
      bool done;
      try {
        // The OTP is checked first (wrong → 400); far from the drop the API then asks for a reason.
        done = await runWithFarCheck(context, (r) => c.completeDelivery(otp: _code, farReason: r),
            target: _job.drop.location);
      } on ApiException catch (e) {
        if (!mounted) return;
        lockIfOtpLocked(e);
        _fail(e.message);
        return;
      } on Exception catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        showTtSnack(context, userMessage(e));
        return;
      }
      if (!mounted) return;
      if (!done) {
        setState(() => _busy = false);
        return;
      }
      context.pushReplacement(Routes.collectDelivery);
      return;
    }
    if (!c.verifyDeliveryOtp(_code)) {
      _fail('Wrong OTP, please try again');
      return;
    }
    if (widget.showcase) return showTtSnack(context, kPreviewNote);
    await c.completeDelivery();
    if (mounted) context.pushReplacement(Routes.collectDelivery);
  }

  @override
  Widget build(BuildContext context) {
    final receiver = _job.parcel?.receiverName ?? _job.customerName;
    final phone = _job.parcel?.receiverPhone ?? _job.customerPhone;
    return OtpStepScaffold(
      onJob:
          !widget.showcase &&
          ref.watch(driverSessionProvider.select((s) => s.job != null)),
      delivery: true,
      appBarTitle: 'Complete delivery',
      title: 'Ask ${receiver.split(' ').first} for the delivery OTP',
      subtitle: _api
          ? 'The sender sees it in their Tamil Taxi app and shares it with them.'
          : 'It was sent to $phone by SMS.',
      otp: OtpInput(
        length: 4,
        boxSize: 80,
        autofocus: !widget.showcase,
        initialValue: _code,
        hasError: _errorText != null,
        shakeTrigger: _shake,
        onChanged: (v) => setState(() {
          _code = v;
          if (!isOtpLocked) _errorText = null;
        }),
      ),
      error: _errorText,
      extra: PhotoAttachmentTile(
        photo: _photo,
        camera: true,
        label: 'Take photo of delivered parcel',
        onChanged: (photo) async {
          setState(() => _photo = photo);
          if (_api && photo != null) await _uploadPhoto(photo);
        },
      ),
      buttonLabel: 'Complete delivery',
      busy: _busy,
      onSubmit: _code.length == 4 && !isOtpLocked ? _complete : null,
    );
  }
}
