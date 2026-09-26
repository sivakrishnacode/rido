import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/map_insets.dart';
import '../../router/routes.dart';
import '../../state/parcel_flow.dart';
import 'widgets/parcel_widgets.dart';

/// PP-06 Choose goods vehicle and review: route map, goods vehicles filtered by weight,
/// who pays, fare breakdown and Book.
class PP06ChooseGoodsVehicleScreen extends ConsumerStatefulWidget {
  const PP06ChooseGoodsVehicleScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<PP06ChooseGoodsVehicleScreen> createState() => _PP06ChooseGoodsVehicleScreenState();
}

class _PP06ChooseGoodsVehicleScreenState extends ConsumerState<PP06ChooseGoodsVehicleScreen> {
  @override
  void initState() {
    super.initState();
    // Live API: the fares shown and booked are the server's goods quotes.
    if (!widget.showcase) Future.microtask(() => ref.read(parcelFlowProvider.notifier).loadQuotes());
  }

  Future<void> _book() async {
    final error = await ref.read(parcelFlowProvider.notifier).book();
    if (!mounted) return;
    if (error != null) {
      showRidoSnack(context, error);
      return;
    }
    context.go(Routes.parcelFinding);
  }

  void _showFare(BuildContext context, FareQuote q) {
    showRidoSheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FareBreakdown.fromQuote(q, title: 'Fare breakdown', subtitle: '${q.vehicle.name} · ${formatKm(q.distanceKm)}'),
          const SizedBox(height: 8),
          Text('Pay the driver directly by cash or UPI. Rido takes no commission.',
              style: ctx.type.caption.copyWith(color: RidoColors.navy500)),
          const SizedBox(height: 16),
          RidoButton(label: 'Got it', onPressed: () => Navigator.of(ctx).pop()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final s = ref.watch(parcelFlowProvider);
    final ctrl = ref.read(parcelFlowProvider.notifier);
    // Live API: wait for the server's quotes; never show a locally computed fare.
    final quotesReady = widget.showcase || !ref.watch(isLiveApiProvider) || s.serverQuotes != null;
    final quotes = s.quotes;
    final quote = s.quote;
    final canBook = quotesReady && s.fits(quote.vehicle) && !s.busy;
    final height = MediaQuery.sizeOf(context).height;
    final top = MediaQuery.paddingOf(context).top;
    final insets = sheetMapInsets(EdgeInsets.fromLTRB(56, top + 96, 56, height * 0.64 + 24), height * 0.64);

    return Scaffold(
      backgroundColor: RidoColors.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: RidoMap(
              pickup: s.pickup.location,
              drop: s.drop.location,
              route: s.routeOrDefault,
              fitPoints: s.routeOrDefault,
              fitPadding: insets.fit,
              mapPadding: insets.map,
              attributionAlignment: Alignment.topRight,
            ),
          ),
          Positioned(
            top: top + 12,
            left: 16,
            child: MapCircleButton(
              icon: Symbols.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: () => context.canPop() ? context.pop() : context.go(Routes.parcel),
            ),
          ),
          Positioned(
            top: top + 16,
            right: 16,
            child: _RouteChip(label: quotesReady ? s.estimate.label : 'Getting fares…'),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ParcelSheetPanel(
              maxHeight: height * 0.66,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                flex: 3,
                                child: Text('Choose a vehicle', style: t.h1, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${s.details.category.label} · ${s.details.weight.label}',
                                  textAlign: TextAlign.right,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.caption.copyWith(color: RidoColors.navy700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (!quotesReady)
                            _QuotesPending(error: s.quotesError, onRetry: ctrl.loadQuotes)
                          else
                          for (final q in quotes) ...[
                            VehicleOptionCard(
                              icon: q.vehicle.kind.icon,
                              name: q.vehicle.name,
                              subtitle: '${q.vehicle.etaMin} min away · ${q.vehicle.capacityLabel.toLowerCase()}',
                              fare: q.total,
                              badge: q.vehicle.badge,
                              selected: q.vehicle.kind == s.vehicle,
                              disabledReason: s.fits(q.vehicle) ? null : 'Too small for ${s.details.weight.label}',
                              onTap: () => ctrl.selectVehicle(q.vehicle.kind),
                            ),
                            const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 6),
                          Text('Who pays the driver?', style: t.bodyMedium),
                          const SizedBox(height: 10),
                          RidoSegmented<ParcelPayer>(
                            options: ParcelPayer.values,
                            labelOf: (p) => p == ParcelPayer.sender ? 'Sender (me)' : 'Receiver',
                            selected: s.details.payer,
                            onChanged: ctrl.setPayer,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Symbols.back_hand_rounded, size: 20, color: RidoColors.navy700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Loading and unloading is done by the sender and receiver.',
                                    style: t.bodySmall.copyWith(color: RidoColors.navy700)),
                              ),
                              TextButton(
                                onPressed: quotesReady ? () => _showFare(context, quote) : null,
                                style: TextButton.styleFrom(
                                  foregroundColor: RidoColors.coral600,
                                  minimumSize: const Size(48, 48),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  textStyle: t.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                ),
                                child: const Text('Fare breakdown'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rido connects you with drivers and is not liable for lost or damaged goods.',
                            style: t.caption.copyWith(color: RidoColors.navy500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: RidoButton(
                      label: quotesReady ? 'Book ${quote.vehicle.name} · ${formatInr(quote.total)}' : 'Book',
                      loading: s.busy,
                      onPressed: canBook ? _book : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteChip extends StatelessWidget {
  const _RouteChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const BoxDecoration(color: RidoColors.surface, borderRadius: RidoRadii.pillRadius, boxShadow: RidoShadows.soft),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.route_rounded, size: 18, color: RidoColors.coral600),
            const SizedBox(width: 6),
            Text(label, style: RidoTextStyles.tabular(context.type.bodySmallMedium.copyWith(color: RidoColors.navy900))),
          ],
        ),
      );
}

/// Live API: goods fares are loading, or failed with [error] and a Retry.
class _QuotesPending extends StatelessWidget {
  const _QuotesPending({required this.error, required this.onRetry});
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error;
    if (message == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(message, style: context.type.body.copyWith(color: RidoColors.navy700), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          RidoButton.text(label: 'Try again', onPressed: onRetry),
        ],
      ),
    );
  }
}
