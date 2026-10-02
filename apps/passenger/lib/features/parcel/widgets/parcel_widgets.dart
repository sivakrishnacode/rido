import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' show Distance, LengthUnit;
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../../common/launch.dart';
import '../../../common/place_search.dart';
import '../../../router/routes.dart';
import '../../../state/parcel_flow.dart';

/// Stepper labels shared by PP-08 and PP-09.
const parcelSteps = ['Driver assigned', 'At pickup', 'Picked up', 'Delivered'];

/// "Peelamedu, Avinashi Rd": the place name plus the first part of its address,
/// unless that part already repeats the name.
String shortAddress(Place p) {
  final first = p.address.split(',').first.trim();
  return first.contains(p.name) || p.name.contains(first) ? p.name : '${p.name}, $first';
}

/// "+91 94433 21098" → "94433 21098" (digits formatted 5 + 5).
String localPhone(String phone) {
  var d = phone.replaceAll(RegExp(r'\D'), '');
  if (d.length > 10 && d.startsWith('91')) d = d.substring(d.length - 10);
  return d.length > 5 ? '${d.substring(0, 5)} ${d.substring(5)}' : d;
}

/// Digits only.
String phoneDigits(String text) => text.replaceAll(RegExp(r'\D'), '');

/// "98765 43210" → "+919876543210" (the format the API stores; show it with `displayPhone`).
String fullPhone(String text) => apiPhone(text);

/// Flat vehicle "illustration": a coral-50 tile with a filled coral vehicle symbol.
class ParcelVehicleArt extends StatelessWidget {
  const ParcelVehicleArt({super.key, required this.kind, this.width = 64, this.height = 52, this.tile = TtColors.coral50});

  final VehicleKind kind;
  final double width;
  final double height;
  final Color tile;

  /// The vehicle's render when it has one ([VehicleArt]); otherwise the coral symbol on a [tile].
  @override
  Widget build(BuildContext context) => kind.artAsset != null
      ? VehicleArt(kind, width: width, height: height)
      : Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: tile, borderRadius: TtRadii.cardRadius),
          alignment: Alignment.center,
          child: Icon(kind.icon, fill: 1, color: TtColors.coral500, size: math.min(width, height) * 0.66),
        );
}

/// Passenger app bar with a "Step x of 3" caption on the right (PP-02 … PP-04).
class ParcelStepAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ParcelStepAppBar({super.key, required this.title, required this.step});

  final String title;
  final int step;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => TtAppBar(
        title: title,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text('Step $step of 3', style: context.type.bodySmall.copyWith(color: TtColors.navy500)),
            ),
          ),
        ],
      );
}

/// The pickup (PP-02) or drop (PP-03) in one compact row: its pin, name and address, and "Change".
class ParcelLocationCard extends StatelessWidget {
  const ParcelLocationCard({super.key, required this.place, required this.isPickup, required this.onChange});

  final Place place;
  final bool isPickup;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final color = isPickup ? TtColors.success : TtColors.coral500;
    return Material(
      color: TtColors.surface,
      shape: RoundedRectangleBorder(borderRadius: TtRadii.cardRadius, side: const BorderSide(color: TtColors.divider)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onChange,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Symbols.location_on_rounded, fill: 1, size: 20, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name, style: t.bodySemibold, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (place.address.isNotEmpty)
                      Text(place.address,
                          style: t.bodySmall.copyWith(color: TtColors.navy500), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              TextButton(
                onPressed: onChange,
                style: TextButton.styleFrom(
                  foregroundColor: TtColors.coral600,
                  minimumSize: const Size(48, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: t.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                child: const Text('Change'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Share tracking": opens the SMS app to the receiver with the driver, vehicle, drop, where the vehicle is
/// now and the delivery OTP they give the driver at drop-off.
Future<void> shareParcelWithReceiver(BuildContext context, ParcelFlowState s, LatLng? vehicleAt) {
  final d = s.details;
  final sender = d.senderName.trim().isEmpty ? 'Sender' : d.senderName.split(' ').first;
  final text = [
    tripShareText(
      riderName: sender,
      driver: s.driver,
      vehicleLabel: s.vehicle.label,
      drop: s.drop,
      vehicleAt: vehicleAt,
      parcel: true,
    ),
    'Delivery OTP: ${d.deliveryOtp} (give it to the driver at drop-off)',
  ].join('\n');
  return openSms(context, text, to: d.receiverPhone);
}

/// Searches places ([showPlaceSearchSheet]: Google via the API when live, seed places in mock mode) and
/// returns the picked one with its coordinates resolved.
Future<Place?> showParcelPlacePicker(BuildContext context, {required String title, Place? current, bool anywhere = false}) async {
  final pick = await showPlaceSearchSheet(context, title: title, current: current, anywhere: anywhere);
  return pick?.place;
}

/// Opens PP-03. With no drop chosen yet it searches first, so PP-03 never starts on a place the sender didn't
/// pick; backing out of the search stays where they were.
Future<void> openParcelDrop(BuildContext context, WidgetRef ref) async {
  final s = ref.read(parcelFlowProvider);
  if (!s.dropSet) {
    final p = await showParcelPlacePicker(context, title: s.outstation ? 'Deliver to (any town)' : 'Deliver to', anywhere: s.outstation);
    if (p == null || !context.mounted) return;
    ref.read(parcelFlowProvider.notifier).setDrop(p);
  }
  if (context.mounted) await context.push(Routes.parcelDrop);
}

/// The map on top of PP-02 / PP-03: the point under a fixed pin. Moving the map by hand moves the point ([onMoved]
/// gets it with its address once the map rests); a new [place] (picked in search) glides the camera there.
class ParcelPinMap extends ConsumerStatefulWidget {
  const ParcelPinMap({
    super.key,
    required this.place,
    required this.isPickup,
    required this.onMoved,
    this.folded = false,
    this.height = 180,
    this.interactive = true,
  });

  final Place place;
  final bool isPickup;
  final ValueChanged<Place> onMoved;

  /// Folded away (the keyboard is up: the form keeps the room). The screen tells: inside its Scaffold the
  /// keyboard inset is already taken out.
  final bool folded;
  final double height;
  final bool interactive;

  @override
  ConsumerState<ParcelPinMap> createState() => _ParcelPinMapState();
}

class _ParcelPinMapState extends ConsumerState<ParcelPinMap> {
  static const double _zoom = 16;
  final _map = TtMapController();
  late final LatLng _start = widget.place.location;
  late LatLng _centre = _start;
  Timer? _debounce;
  int _request = 0;
  bool _locating = false;

  /// A finger moved the map since the last address lookup (the map also reports its own camera moves).
  bool _touched = false;
  int _down = 0;

  @override
  void didUpdateWidget(covariant ParcelPinMap old) {
    super.didUpdateWidget(old);
    final to = widget.place.location;
    // A place from search, not this map's own move: take the camera there.
    if (to != old.place.location && const Distance().as(LengthUnit.Meter, to, _centre) > 25) {
      _centre = to;
      _debounce?.cancel();
      _request++;
      _locating = false;
      _map.animateTo(to, _zoom);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _map.dispose();
    super.dispose();
  }

  void _onMove(TtCamera camera, bool hasGesture) {
    if (!_touched) return;
    _centre = camera.center;
    _debounce?.cancel();
    if (!_locating) setState(() => _locating = true);
    _debounce = Timer(const Duration(milliseconds: 400), _geocode);
  }

  Future<void> _geocode() async {
    if (_down == 0) _touched = false;
    final id = ++_request;
    final centre = _centre;
    Place place;
    try {
      place = await ref.read(placesRepositoryProvider).reverseGeocode(centre);
    } catch (_) {
      // Offline / API error: keep the exact pin without an address.
      place = Place(id: 'pin-${centre.latitude},${centre.longitude}', name: 'Pinned location', address: '', location: centre);
    }
    if (!mounted || id != _request) return;
    setState(() => _locating = false);
    widget.onMoved(place.copyWith(location: centre));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final label = _locating ? 'Finding the address…' : (widget.isPickup ? 'Pickup here' : 'Drop here');
    // Folds by clipping, not resizing: the native map keeps its size and doesn't re-lay out every frame.
    return ClipRect(
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        heightFactor: widget.folded ? 0 : 1,
        child: SizedBox(
          height: widget.height,
          child: Semantics(
            label: '${widget.isPickup ? 'Pickup' : 'Drop'} on the map. Move the map to adjust the point',
            child: Stack(
              children: [
                Positioned.fill(
                  child: Listener(
                    onPointerDown: (_) {
                      _down++;
                      _touched = true;
                    },
                    onPointerUp: (_) => _down = math.max(0, _down - 1),
                    onPointerCancel: (_) => _down = math.max(0, _down - 1),
                    child: TtMap(
                      controller: _map,
                      center: _start,
                      zoom: _zoom,
                      interactive: widget.interactive,
                      onPositionChanged: _onMove,
                    ),
                  ),
                ),
                // Fixed pin: its tip on the map's centre.
                IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 70),
                      child: SizedBox(
                        height: 70,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: Container(
                                key: ValueKey(label),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: const BoxDecoration(color: TtColors.navy900, borderRadius: TtRadii.pillRadius),
                                child: Text(label, style: t.caption.copyWith(color: TtColors.surface, fontWeight: FontWeight.w600)),
                              ),
                            ),
                            Icon(Symbols.location_on_rounded,
                                fill: 1, size: 44, color: widget.isPickup ? TtColors.success : TtColors.coral500),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = phoneDigits(newValue.text);
    final d = digits.substring(0, math.min(10, digits.length));
    final text = d.length > 5 ? '${d.substring(0, 5)} ${d.substring(5)}' : d;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// "+91" phone field like [PhoneInput], with an optional trailing action (contacts).
class ParcelPhoneField extends StatelessWidget {
  const ParcelPhoneField({
    super.key,
    required this.label,
    required this.controller,
    this.errorText,
    this.onChanged,
    this.suffix,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: t.bodySmallMedium.copyWith(color: TtColors.navy700)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          inputFormatters: [_PhoneFormatter()],
          onChanged: onChanged,
          style: TtTextStyles.tabular(t.body.copyWith(letterSpacing: 0.5)),
          decoration: InputDecoration(
            hintText: '98765 43210',
            errorText: errorText,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('+91', style: t.body),
                  const SizedBox(width: 12),
                  Container(width: 1, height: 24, color: TtColors.divider),
                ],
              ),
            ),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

/// Round action with a caption underneath (PP-08 Call / Chat / Share tracking / Cancel).
class ParcelRoundAction extends StatelessWidget {
  const ParcelRoundAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.bg,
    required this.fg,
    this.labelColor = TtColors.navy900,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color bg;
  final Color fg;
  final Color labelColor;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: TtRadii.cardRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                  child: Icon(icon, color: fg, fill: 1, size: 22),
                ),
                const SizedBox(height: 6),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.bodySmallMedium.copyWith(color: labelColor)),
              ],
            ),
          ),
        ),
      );
}

/// Small grey pill ("Clothes / Textiles", "5–20 kg").
class ParcelTag extends StatelessWidget {
  const ParcelTag(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: const BoxDecoration(color: TtColors.inputBg, borderRadius: TtRadii.pillRadius),
        child: Text(text, style: context.type.bodySmallMedium.copyWith(color: TtColors.navy700)),
      );
}

/// White "sheet" panel with rounded top corners and a handle, for map screens.
class ParcelSheetPanel extends StatelessWidget {
  const ParcelSheetPanel({super.key, required this.child, this.maxHeight});

  final Widget child;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight ?? double.infinity),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: TtColors.surface,
            borderRadius: TtRadii.sheetTop,
            boxShadow: TtShadows.raised,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [const SheetHandle(), Flexible(child: child)],
            ),
          ),
        ),
      );
}
