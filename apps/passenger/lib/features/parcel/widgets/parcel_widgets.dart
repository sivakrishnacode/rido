import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' show Marker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

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

/// "98765 43210" → "+91 98765 43210".
String fullPhone(String text) => '+91 ${localPhone(text)}';

/// Flat vehicle "illustration": a coral-50 tile with a filled coral vehicle symbol.
class ParcelVehicleArt extends StatelessWidget {
  const ParcelVehicleArt({super.key, required this.kind, this.width = 64, this.height = 52, this.tile = RidoColors.coral50});

  final VehicleKind kind;
  final double width;
  final double height;
  final Color tile;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: tile, borderRadius: RidoRadii.cardRadius),
        alignment: Alignment.center,
        child: Icon(kind.icon, fill: 1, color: RidoColors.coral500, size: math.min(width, height) * 0.66),
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
  Widget build(BuildContext context) => RidoAppBar(
        title: title,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text('Step $step of 3', style: context.type.bodySmall.copyWith(color: RidoColors.navy500)),
            ),
          ),
        ],
      );
}

/// Small map + address + "Change" (PP-02 pickup, PP-03 drop).
class ParcelLocationCard extends StatelessWidget {
  const ParcelLocationCard({super.key, required this.place, required this.isPickup, required this.onChange});

  final Place place;
  final bool isPickup;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Container(
      decoration: BoxDecoration(
        color: RidoColors.surface,
        borderRadius: RidoRadii.cardRadius,
        border: Border.all(color: RidoColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 140,
            child: RidoMap(
              key: ValueKey(place.id),
              center: place.location,
              zoom: 15.5,
              interactive: false,
              showAttribution: false,
              extraMarkers: [
                Marker(
                  point: place.location,
                  width: 44,
                  height: 44,
                  alignment: Alignment.topCenter,
                  child: Icon(
                    Symbols.location_on_rounded,
                    fill: 1,
                    size: 44,
                    color: isPickup ? RidoColors.success : RidoColors.coral500,
                    shadows: const [Shadow(color: RidoColors.shadow, blurRadius: 6, offset: Offset(0, 2))],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place.name, style: t.bodySemibold.copyWith(fontSize: 17), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(place.address,
                          style: t.bodySmall.copyWith(color: RidoColors.navy500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onChange,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 44),
                    foregroundColor: RidoColors.navy900,
                    side: const BorderSide(color: RidoColors.divider),
                    shape: const StadiumBorder(),
                    textStyle: t.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a sheet listing [Seed.places]; returns the picked place, resolved through
/// [PlacesRepository.resolve] (a no-op for seed places).
Future<Place?> showParcelPlacePicker(BuildContext context, {required String title, Place? current}) async {
  final places = ProviderScope.containerOf(context, listen: false).read(placesRepositoryProvider);
  final picked = await showRidoSheet<Place>(
    context,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: ctx.type.h2),
        const SizedBox(height: 8),
        for (final p in Seed.places)
          RidoListTile(
            icon: Symbols.location_on_rounded,
            title: p.name,
            subtitle: p.address,
            showChevron: false,
            trailing: p == current ? const Icon(Symbols.check_rounded, color: RidoColors.coral600) : null,
            onTap: () => Navigator.of(ctx).pop(p),
          ),
      ],
    ),
  );
  if (picked == null) return null;
  try {
    return await places.resolve(picked);
  } on OfflineException {
    return null;
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
  });

  final String label;
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: t.bodySmallMedium.copyWith(color: RidoColors.navy700)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          inputFormatters: [_PhoneFormatter()],
          onChanged: onChanged,
          style: RidoTextStyles.tabular(t.body.copyWith(letterSpacing: 0.5)),
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
                  Container(width: 1, height: 24, color: RidoColors.divider),
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
    this.labelColor = RidoColors.navy900,
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
          borderRadius: RidoRadii.cardRadius,
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
        decoration: const BoxDecoration(color: RidoColors.inputBg, borderRadius: RidoRadii.pillRadius),
        child: Text(text, style: context.type.bodySmallMedium.copyWith(color: RidoColors.navy700)),
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
            color: RidoColors.surface,
            borderRadius: RidoRadii.sheetTop,
            boxShadow: RidoShadows.raised,
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
