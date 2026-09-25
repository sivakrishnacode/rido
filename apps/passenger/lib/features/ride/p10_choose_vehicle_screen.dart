import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/ride_flow.dart';
import 'p11_fare_details_sheet.dart';

/// P-10 Choose vehicle: route map, Bike / Auto / Cab cards, payment note, women-driver
/// preference and "Book Bike · ₹38".
class P10ChooseVehicleScreen extends ConsumerWidget {
  const P10ChooseVehicleScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  void _book(BuildContext context, WidgetRef ref) {
    final state = ref.read(rideFlowProvider);
    final places = ref.read(placesRepositoryProvider);
    final outside =
        ref.read(demoSettingsProvider).outsideServiceArea ||
        !places.isInServiceArea(state.pickup.location) ||
        !places.isInServiceArea(state.drop.location);
    if (outside) {
      context.push(Routes.serviceUnavailable);
      return;
    }
    ref.read(rideFlowProvider.notifier).book();
    context.go(Routes.findingDriver);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final state = ref.watch(rideFlowProvider);
    final flow = ref.read(rideFlowProvider.notifier);
    final quote = state.quote;
    final route = state.routeOrDefault;

    return Scaffold(
      backgroundColor: RidoColors.surface,
      body: LayoutBuilder(
        builder: (context, c) {
          final sheetH = (c.maxHeight * 0.66).clamp(360.0, 580.0).toDouble();
          final mapH = c.maxHeight - sheetH + RidoSpacing.l;
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: mapH,
                child: RidoMap(
                  pickup: state.pickup.location,
                  drop: state.drop.location,
                  route: route,
                  fitPoints: route,
                  fitPadding: const EdgeInsets.fromLTRB(56, 96, 56, 88),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.m, 0, 0),
                    child: MapCircleButton(
                      icon: Symbols.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () => context.canPop() ? context.pop() : context.go(Routes.ride),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: mapH - 76,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l, vertical: RidoSpacing.s),
                    decoration: const BoxDecoration(
                      color: RidoColors.surface,
                      borderRadius: RidoRadii.pillRadius,
                      boxShadow: RidoShadows.soft,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Symbols.conversion_path_rounded, size: 20, color: RidoColors.coral600),
                        const SizedBox(width: RidoSpacing.s),
                        Text(state.estimate.label, style: RidoTextStyles.tabular(t.bodySemibold)),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: sheetH,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: RidoColors.surface,
                    borderRadius: RidoRadii.sheetTop,
                    boxShadow: RidoShadows.raised,
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        const SheetHandle(),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.l),
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text('Choose a ride', style: t.h1)),
                                  TextButton(
                                    onPressed: () => P11FareDetailsSheet.show(context),
                                    style: TextButton.styleFrom(
                                      foregroundColor: RidoColors.coral600,
                                      minimumSize: const Size(48, 48),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Fare details',
                                          style: t.bodySemibold.copyWith(color: RidoColors.coral600),
                                        ),
                                        const Icon(Symbols.chevron_right_rounded, size: 20),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: RidoSpacing.s),
                              for (final q in state.quotes) ...[
                                VehicleOptionCard(
                                  icon: q.vehicle.kind.icon,
                                  name: q.vehicle.name,
                                  subtitle: '${q.vehicle.etaMin} min away · ${q.vehicle.capacityLabel}',
                                  fare: q.total,
                                  badge: q.vehicle.badge,
                                  badgeTone: q.vehicle.badge == 'Comfort' || q.vehicle.badge == 'Fastest'
                                      ? VehicleBadgeTone.navy
                                      : VehicleBadgeTone.coral,
                                  selected: q.vehicle.kind == state.vehicle,
                                  onTap: () => flow.selectVehicle(q.vehicle.kind),
                                ),
                                const SizedBox(height: RidoSpacing.s),
                              ],
                              const Divider(height: RidoSpacing.l),
                              Row(
                                children: [
                                  const Icon(Symbols.payments_rounded, color: RidoColors.navy900),
                                  const SizedBox(width: RidoSpacing.m),
                                  Flexible(
                                    child: Text(
                                      'Cash / UPI to driver',
                                      style: t.bodyMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: RidoSpacing.s),
                                  Flexible(
                                    child: Material(
                                      color: RidoColors.inputBg,
                                      shape: const StadiumBorder(),
                                      clipBehavior: Clip.antiAlias,
                                      child: InkWell(
                                        onTap: () => showRidoSnack(
                                          context,
                                          'Pay your driver by cash or UPI when the ride ends. Rido takes 0% of it.',
                                        ),
                                        child: Container(
                                          constraints: const BoxConstraints(minHeight: 40),
                                          padding: const EdgeInsets.symmetric(horizontal: RidoSpacing.m),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Symbols.info_rounded, size: 18, color: RidoColors.navy700),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  'Pay your driver directly',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: t.bodySmall.copyWith(color: RidoColors.navy700),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: RidoSpacing.xl),
                              MergeSemantics(
                                child: Row(
                                  children: [
                                    const Icon(Symbols.woman_rounded, color: RidoColors.navy900),
                                    const SizedBox(width: RidoSpacing.m),
                                    Expanded(child: Text('Prefer women driver', style: t.bodyMedium)),
                                    Switch(value: state.preferWomenDriver, onChanged: flow.setPreferWomenDriver),
                                  ],
                                ),
                              ),
                              const SizedBox(height: RidoSpacing.s),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            RidoSpacing.l,
                            RidoSpacing.s,
                            RidoSpacing.l,
                            RidoSpacing.l,
                          ),
                          child: RidoButton(
                            label: 'Book ${quote.vehicle.name} · ${formatInr(quote.total)}',
                            onPressed: () => _book(context, ref),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
