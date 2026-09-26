import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/phone.dart';
import '../../common/trip_routes.dart';
import '../../router/routes.dart';
import '../../state/parcel_flow.dart';
import 'widgets/parcel_widgets.dart';

/// PP-07 Finding a goods driver: pulse on the pickup, progress, booking summary, Cancel.
/// Shows an inline "no drivers" state with Retry when the search fails.
class PP07FindingGoodsDriverScreen extends ConsumerStatefulWidget {
  const PP07FindingGoodsDriverScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<PP07FindingGoodsDriverScreen> createState() => _PP07FindingGoodsDriverScreenState();
}

class _PP07FindingGoodsDriverScreenState extends ConsumerState<PP07FindingGoodsDriverScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: ref.read(simTimingProvider)(SimTimings.findGoodsDriver));
    if (widget.showcase || ref.read(parcelFlowProvider).phase != ParcelPhase.searching) {
      _progress.value = 0.37;
    } else {
      _progress.forward();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    final error = await ref.read(parcelFlowProvider.notifier).cancel();
    if (!mounted) return;
    if (error != null) {
      showRidoSnack(context, error);
      return;
    }
    context.go(Routes.parcel);
  }

  /// Books again (a new request when live).
  Future<void> _retry() async {
    final error = await ref.read(parcelFlowProvider.notifier).book();
    if (!mounted) return;
    if (error != null) {
      showRidoSnack(context, error);
      return;
    }
    _progress.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(parcelFlowProvider.select((s) => s.phase), (prev, next) {
      if (widget.showcase || next == ParcelPhase.searching || next == ParcelPhase.noDrivers) return;
      // Assigned, or further along when a poll skipped steps.
      final route = routeForParcelPhase(next);
      if (route != null) context.go(route);
    });
    final s = ref.watch(parcelFlowProvider);
    final noDrivers = !widget.showcase && s.phase == ParcelPhase.noDrivers;
    final height = MediaQuery.sizeOf(context).height;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.parcel);
      },
      child: Scaffold(
        backgroundColor: RidoColors.surface,
        body: Stack(
          children: [
            Positioned.fill(
              bottom: height * 0.4,
              child: RidoMap(
                center: s.pickup.location,
                zoom: 15,
                pickup: s.pickup.location,
                pulseAt: noDrivers ? null : s.pickup.location,
                interactive: false,
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ParcelSheetPanel(
                maxHeight: height * 0.7,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: noDrivers ? _NoDrivers(state: s, onRetry: _retry, onCancel: _cancel) : _searching(context, s),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searching(BuildContext context, ParcelFlowState s) {
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ParcelVehicleArt(kind: s.vehicle, width: 64, height: 52),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Finding a nearby ${s.vehicle.label}…', style: t.h1),
                  Text('Usually 1–2 minutes', style: t.body.copyWith(color: RidoColors.navy700)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _progress,
          builder: (context, _) => ClipRRect(
            borderRadius: RidoRadii.pillRadius,
            child: LinearProgressIndicator(
              value: 0.08 + 0.9 * _progress.value,
              minHeight: 6,
              color: RidoColors.coral500,
              backgroundColor: RidoColors.coral50,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SummaryCard(state: s),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [ParcelTag(s.details.category.label), ParcelTag(s.details.weight.label)],
        ),
        const SizedBox(height: 16),
        Center(
          child: RidoButton(
            label: 'Cancel',
            variant: RidoButtonVariant.dangerText,
            expand: false,
            onPressed: _cancel,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.state});
  final ParcelFlowState state;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final d = state.details;
    final sender = d.senderName.split(' ').first;
    final pickupSub = d.pickupNote.isEmpty ? sender : '$sender · ${d.pickupNote}';
    final dropSub = '${d.receiverName} · ${displayPhone(d.receiverPhone)}';
    return RidoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickupDropConnector(
            pickupTitle: state.pickup.name,
            pickupSubtitle: pickupSub,
            dropTitle: state.drop.name,
            dropSubtitle: dropSub,
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  d.payer == ParcelPayer.sender ? 'You pay · Cash / UPI' : 'Receiver pays · Cash / UPI',
                  style: t.bodySmall.copyWith(color: RidoColors.navy500),
                ),
              ),
              Text(formatInr(state.quote.total), style: RidoTextStyles.tabular(t.h1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoDrivers extends StatelessWidget {
  const _NoDrivers({required this.state, required this.onRetry, required this.onCancel});
  final ParcelFlowState state;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RidoIllustration(IllustrationKind.noDrivers, width: 160, height: 120),
        const SizedBox(height: 12),
        Text('No ${state.vehicle.label}s nearby right now', style: t.h1, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('All nearby drivers are busy. Try again in a minute, or pick a bigger vehicle.',
            style: t.body.copyWith(color: RidoColors.navy700), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        RidoButton(label: 'Retry', icon: Symbols.refresh_rounded, onPressed: onRetry),
        const SizedBox(height: 4),
        RidoButton(label: 'Cancel', variant: RidoButtonVariant.dangerText, onPressed: onCancel),
      ],
    );
  }
}
