import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_account.dart';
import '../../state/driver_session.dart';
import '../home/widgets/navy_header.dart';
import 'widgets/job_common.dart';
import 'widgets/rate_customer_sheet.dart';

/// D-19 Collect payment (and D-22b for deliveries): "Collect ₹38", the driver's own UPI QR,
/// "Received cash" / "Received on UPI" → rate the passenger → D-14 with today's earnings up.
class D19CollectPaymentScreen extends ConsumerStatefulWidget {
  const D19CollectPaymentScreen({super.key, this.delivery = false, this.showcase = false});

  /// D-22b "Collect from receiver" variant.
  final bool delivery;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D19CollectPaymentScreen> createState() => _D19CollectPaymentScreenState();
}

class _D19CollectPaymentScreenState extends ConsumerState<D19CollectPaymentScreen> {
  late final RideRequest _job = ref.read(driverSessionProvider).job ??
      (widget.delivery ? Seed.deliveryRequest : Seed.rideRequest);
  bool _busy = false;

  bool get _isDelivery => widget.delivery || _job.isDelivery;

  String get _rateName => _isDelivery ? (_job.parcel?.receiverName ?? _job.customerName) : _job.customerName;

  Future<void> _received(PaymentMode mode) async {
    if (_busy) return;
    final stars = await RateCustomerSheet.show(context, name: _rateName.split(' ').first);
    if (stars == null || !mounted) return;
    setState(() => _busy = true);
    if (!widget.showcase) await ref.read(driverSessionProvider.notifier).collectPayment(mode);
    if (!mounted) return;
    showTtSnack(context, '${formatInr(_job.fare)} added. You keep 100%.', success: true);
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final profile = ref.watch(driverProfileProvider).value ?? Seed.karthik;
    // Demo: a delivery shown with the bike driver's profile pays the seed goods driver. Live: always you.
    final demoGoods = !ref.watch(isLiveApiProvider) && _isDelivery && !profile.vehicleKind.isGoods;
    final upi = demoGoods ? Seed.selvam.upiId : profile.upiId;
    final payee = demoGoods ? Seed.selvam.name : profile.name;
    final qrData = 'upi://pay?pa=$upi&pn=${Uri.encodeComponent(payee)}&am=${_job.fare}&cu=INR';
    final fromReceiver = _job.parcel?.payer != ParcelPayer.sender;
    final live = !widget.showcase && ref.watch(driverSessionProvider.select((s) => s.job)) != null;

    return PopScope(
      canPop: !live,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) confirmLeaveJob(context, delivery: _isDelivery);
      },
      child: Scaffold(
        backgroundColor: TtColors.surface,
        body: Column(
          children: [
            NavyHeader(
              padding: const EdgeInsets.fromLTRB(TtSpacing.gutter, TtSpacing.l, TtSpacing.gutter, TtSpacing.xl),
              child: SizedBox(
                width: double.infinity,
                child: Column(children: [
                  if (_isDelivery)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: TtSpacing.m, vertical: 6),
                      decoration: const BoxDecoration(color: TtColors.success, borderRadius: TtRadii.pillRadius),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Symbols.verified_rounded, fill: 1, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text('Delivered · OTP verified', style: t.bodySmallMedium.copyWith(color: Colors.white)),
                      ]),
                    )
                  else
                    Text('Ride complete · ${_job.customerName}', style: t.body.copyWith(color: Colors.white70)),
                  const SizedBox(height: TtSpacing.xs),
                  FittedBox(
                    child: Text('Collect ${formatInr(_job.fare)}', style: t.heroSmall.copyWith(color: Colors.white)),
                  ),
                  Text(
                    _isDelivery ? 'from ${fromReceiver ? 'receiver' : 'sender'} · Cash or UPI' : 'Cash or UPI',
                    style: t.body.copyWith(color: Colors.white),
                  ),
                ]),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(TtSpacing.gutter, TtSpacing.l, TtSpacing.gutter, TtSpacing.l),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(TtSpacing.m),
                    decoration: BoxDecoration(
                      color: TtColors.surface,
                      borderRadius: const BorderRadius.all(Radius.circular(20)),
                      border: Border.all(color: TtColors.divider),
                      boxShadow: TtShadows.soft,
                    ),
                    child: Stack(alignment: Alignment.center, children: [
                      QrImageView(
                        data: qrData,
                        size: 196,
                        padding: EdgeInsets.zero,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                        semanticsLabel: 'UPI QR code for $upi',
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: TtColors.navy900),
                        dataModuleStyle:
                            const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: TtColors.navy900),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: TtColors.coral500,
                          borderRadius: TtRadii.cardRadius,
                          border: Border.all(color: TtColors.surface, width: 3),
                        ),
                        child: Text('r', style: t.h1.copyWith(color: Colors.white, fontWeight: FontWeight.w700, height: 1)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: TtSpacing.m),
                  Text(upi, style: t.bodySemibold),
                  const SizedBox(height: TtSpacing.s),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: TtSpacing.s, vertical: 2),
                      decoration: const BoxDecoration(color: TtColors.coral50, borderRadius: TtRadii.pillRadius),
                      child: Text('0%',
                          style: t.caption.copyWith(color: TtColors.coral600, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: TtSpacing.s),
                    Flexible(
                      child: Text('You keep 100% of this fare', style: t.body.copyWith(color: TtColors.navy700)),
                    ),
                  ]),
                  const SizedBox(height: TtSpacing.xl),
                  LayoutBuilder(builder: (context, c) {
                    final cash = TtButton.secondary(
                      label: 'Received cash',
                      icon: Symbols.payments_rounded,
                      onPressed: _busy ? null : () => _received(PaymentMode.cash),
                    );
                    final upiButton = TtButton(
                      label: 'Received on UPI',
                      icon: Symbols.qr_code_2_rounded,
                      loading: _busy,
                      onPressed: () => _received(PaymentMode.upi),
                    );
                    // Side by side when there is room (D-19), stacked on narrow phones.
                    if (c.maxWidth >= 400) {
                      return Row(children: [
                        Expanded(child: cash),
                        const SizedBox(width: TtSpacing.m),
                        Expanded(child: upiButton),
                      ]);
                    }
                    return Column(children: [upiButton, const SizedBox(height: TtSpacing.m), cash]);
                  }),
                  const SizedBox(height: TtSpacing.l),
                  Text('Tap once the money is with you. Then rate ${_rateName.split(' ').first}.',
                      textAlign: TextAlign.center, style: t.caption),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
