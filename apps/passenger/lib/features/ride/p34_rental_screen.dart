import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../common/map_insets.dart';
import '../../router/routes.dart';
import '../../state/nearby_vehicles.dart';
import '../../state/pricing.dart';
import '../../state/ride_flow.dart';
import 'widgets/mode_widgets.dart';

/// P-34 Rent a cab: keep a Mini, Sedan or SUV with its driver by the hour (1–12 h packages), stops anywhere.
/// The pickup, a package, now or later (up to 7 days), then the cab: each tier's package price and its rates past
/// the package. Book now → P-12 finding a driver; later → P-36 booked.
class P34RentalScreen extends ConsumerStatefulWidget {
  const P34RentalScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P34RentalScreen> createState() => _P34RentalScreenState();
}

class _P34RentalScreenState extends ConsumerState<P34RentalScreen> {
  static const _defaultPackage = '4h';

  @override
  void initState() {
    super.initState();
    final current = ref.read(rideFlowProvider).mode;
    if (current?.mode != RideMode.rental) {
      // A fresh start (or coming from outstation): a 4 h package, now.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(rideFlowProvider.notifier).startMode(const ModeRequest(mode: RideMode.rental, packageId: _defaultPackage)),
      );
    }
  }

  ModeRequest get _mode =>
      ref.read(rideFlowProvider).mode ?? const ModeRequest(mode: RideMode.rental, packageId: _defaultPackage);

  Future<void> _book() async {
    final flow = ref.read(rideFlowProvider.notifier);
    if (_mode.isLater) {
      final r = await flow.bookForLater();
      if (!mounted) return;
      if (r.error != null) return showTtSnack(context, r.error!);
      final trip = r.trip;
      if (trip == null) return;
      // Too close to its time: the search already started.
      context.go(trip.status == TripStatus.scheduled ? Routes.bookedLater : Routes.findingDriver, extra: trip.status == TripStatus.scheduled ? trip : null);
      return;
    }
    final error = await flow.book();
    if (!mounted) return;
    if (error != null) return showTtSnack(context, error);
    context.go(Routes.findingDriver);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rideFlowProvider);
    final flow = ref.read(rideFlowProvider.notifier);
    final live = ref.watch(isLiveApiProvider) && !widget.showcase;
    final mode = state.mode?.mode == RideMode.rental ? state.mode! : const ModeRequest(mode: RideMode.rental, packageId: _defaultPackage);
    final pricing = watchPricing(ref, state.pickup.location);
    final quotes = !live ? RideModeRates.quotesFor(state.pickup, null, mode, pricing: pricing) : state.serverQuotes;
    final selected = quotes?.where((q) => q.vehicle.kind == state.vehicle).firstOrNull ?? quotes?.firstOrNull;
    final terms = selected?.modeTerms;
    final later = mode.isLater;

    return ModeBookingLayout(
      onBack: () => context.canPop() ? context.pop() : context.go(Routes.ride),
      map: TtMap(
        center: state.pickup.location,
        zoom: 14,
        pickup: state.pickup.location,
        vehicles: nearbyMarkers(ref, state.pickup.location, kinds: RideModeRates.cabTiers),
        mapPadding: sheetMapPadding(TtSpacing.xl),
      ),
      sections: [
        const ModeHeader(
          title: 'Rent a cab',
          subtitle: 'A cab and driver by the hour. Stop as often as you like, go where you need.',
        ),
        ModeSection(
          title: 'Pickup',
          child: _PickupCard(place: state.pickup, onChange: widget.showcase ? null : () => context.push('${Routes.pinOnMap}?for=pickup')),
        ),
        ModeSection(
          title: 'How long?',
          child: RentalPackagePicker(
            selected: mode.packageId ?? _defaultPackage,
            fromPrice: (p) => RideModeRates.rentalTerms(VehicleKind.cab, p.id, pricing: pricing)!.price,
            onChanged: (id) => flow.updateMode(mode.copyWith(packageId: id)),
          ),
        ),
        ModeSection(
          title: 'When?',
          child: WhenChoice(
            at: mode.leaveAt,
            onChanged: (at) => flow.updateMode(at == null ? mode.copyWith(clearLeave: true) : mode.copyWith(leaveAt: at)),
          ),
        ),
        ModeSection(
          title: 'Choose a cab',
          child: ModeCabList(
            quotes: quotes,
            selected: state.vehicle,
            onSelect: flow.selectVehicle,
            error: live ? state.quotesError : null,
            onRetry: flow.loadQuotes,
          ),
        ),
        ModeNotes(notes: [
          (Symbols.local_gas_station_rounded, 'Fuel and driver included in the package'),
          if (terms is RentalTerms)
            (Symbols.more_time_rounded,
                'Past ${terms.package.label}: ${formatInr(terms.extraKmRate)} a km and ${_perMin(terms.extraMinRate)} a minute, added at the end'),
          (Symbols.toll_rounded, 'Tolls and parking are paid by you on the way'),
          if (later) (Symbols.event_available_rounded, 'Free to cancel until we start finding your driver, 30 min before'),
        ]),
      ],
      bottom: TtButton(
        label: selected == null
            ? 'Getting fares…'
            : '${later ? 'Schedule' : 'Book'} ${selected.vehicle.name} · ${formatInr(selected.total)}',
        loading: state.busy,
        // Design gallery: looks ready, does nothing.
        onPressed: selected == null ? null : (widget.showcase ? () {} : _book),
      ),
    );
  }

  static String _perMin(double r) => r == r.roundToDouble() ? formatInr(r) : '₹${r.toStringAsFixed(1)}';
}

/// The pickup with a Change button.
class _PickupCard extends StatelessWidget {
  const _PickupCard({required this.place, required this.onChange});
  final Place place;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Container(
      padding: const EdgeInsets.fromLTRB(TtSpacing.l, TtSpacing.m, TtSpacing.s, TtSpacing.m),
      decoration: BoxDecoration(
        color: TtColors.surface,
        borderRadius: TtRadii.cardRadius,
        border: Border.all(color: TtColors.divider),
      ),
      child: Row(
        children: [
          const PickupDot(),
          const SizedBox(width: TtSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name, style: t.bodySemibold, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (place.address.isNotEmpty)
                  Text(place.address, style: t.bodySmall.copyWith(color: TtColors.navy500), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (onChange != null)
            TextButton(
              onPressed: onChange,
              style: TextButton.styleFrom(foregroundColor: TtColors.coral600, minimumSize: const Size(48, 48)),
              child: const Text('Change'),
            ),
        ],
      ),
    );
  }
}
