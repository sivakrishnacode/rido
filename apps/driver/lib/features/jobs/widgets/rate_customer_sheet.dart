import 'package:flutter/material.dart';
import 'package:rido_ui/rido_ui.dart';

/// Small "Rate Priya" sheet after collecting payment. Pops with the star count, or 0 for Skip.
class RateCustomerSheet extends StatefulWidget {
  const RateCustomerSheet({super.key, required this.name, this.initial = 0});

  final String name;
  final int initial;

  static Future<int?> show(BuildContext context, {required String name}) =>
      showRidoSheet<int>(context, builder: (_) => RateCustomerSheet(name: name));

  @override
  State<RateCustomerSheet> createState() => _RateCustomerSheetState();
}

class _RateCustomerSheetState extends State<RateCustomerSheet> {
  late int _stars = widget.initial;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: RidoSpacing.s),
      Text('Rate ${widget.name}', style: t.h1, textAlign: TextAlign.center),
      const SizedBox(height: RidoSpacing.xs),
      Text('Payment received. How was this trip?', style: t.bodySmall, textAlign: TextAlign.center),
      const SizedBox(height: RidoSpacing.l),
      Center(child: RatingStars.input(value: _stars.toDouble(), onChanged: (v) => setState(() => _stars = v))),
      const SizedBox(height: RidoSpacing.s),
      Text(_stars == 0 ? 'Tap a star' : RatingStars.labels[_stars - 1],
          style: t.bodySmallMedium.copyWith(color: RidoColors.navy500), textAlign: TextAlign.center),
      const SizedBox(height: RidoSpacing.xl),
      RidoButton(label: 'Submit', onPressed: _stars == 0 ? null : () => Navigator.of(context).pop(_stars)),
      const SizedBox(height: RidoSpacing.xs),
      RidoButton.text(label: 'Skip', expand: true, onPressed: () => Navigator.of(context).pop(0)),
    ]);
  }
}
