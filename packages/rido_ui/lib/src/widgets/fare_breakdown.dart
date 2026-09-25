import 'package:flutter/material.dart';
import 'package:rido_data/rido_data.dart';

import '../format.dart';
import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

/// One line in a [FareBreakdown].
class FareLine {
  const FareLine(this.label, this.amount, {this.note, this.tag, this.signed = false, this.emphasis = false});

  final String label;
  final int amount;

  /// Small caption to the right of the label ("4.2 km × ₹5").
  final String? note;

  /// Small pill after the label ("1.1x", "0%").
  final String? tag;

  /// Show "+₹3" instead of "₹3".
  final bool signed;

  /// Bold row (subtotal).
  final bool emphasis;
}

/// Fare breakdown table: labels in navy-700, amounts right-aligned in tabular figures,
/// only the total row is bold.
class FareBreakdown extends StatelessWidget {
  const FareBreakdown({super.key, required this.lines, required this.total, this.title, this.subtitle, this.footer});

  /// Builds the standard lines from a [FareQuote]: base, distance, time, subtotal, peak.
  factory FareBreakdown.fromQuote(FareQuote q, {Key? key, String? title, String? subtitle, Widget? footer}) {
    final perKm = q.vehicle.fareRule.perKm;
    final perKmText = perKm == perKm.roundToDouble() ? perKm.toStringAsFixed(0) : perKm.toStringAsFixed(1);
    return FareBreakdown(
      key: key,
      title: title,
      subtitle: subtitle,
      footer: footer,
      total: q.total,
      lines: [
        FareLine('Base fare', q.base),
        FareLine('Distance', q.distanceCharge, note: '${q.distanceKm.toStringAsFixed(1)} km × ₹$perKmText'),
        FareLine('Time charge', q.timeCharge, note: '${q.durationMin} min'),
        if (q.minFareTopUp > 0) FareLine('Minimum fare top-up', q.minFareTopUp),
        FareLine('Subtotal', q.subtotal, emphasis: true),
        if (q.hasPeak) FareLine('Peak time', q.peakCharge, tag: '${q.multiplier.toStringAsFixed(1)}x', signed: true),
        const FareLine('Rido commission', 0, tag: '0%'),
      ],
    );
  }

  final List<FareLine> lines;
  final int total;
  final String? title;
  final String? subtitle;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    Widget row(FareLine l) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    l.label,
                    style: (l.emphasis ? t.bodyMedium : t.body).copyWith(color: RidoColors.navy700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (l.tag != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: l.label.contains('commission') ? RidoColors.coral50 : RidoColors.warningTint,
                      borderRadius: RidoRadii.pillRadius,
                    ),
                    child: Text(
                      l.tag!,
                      style: t.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: l.label.contains('commission') ? RidoColors.coral600 : RidoColors.warningText,
                      ),
                    ),
                  ),
                ],
                if (l.note != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(l.note!, style: t.caption, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            l.signed ? formatInrSigned(l.amount) : formatInr(l.amount),
            style: RidoTextStyles.tabular(
              (l.emphasis ? t.bodySemibold : t.bodyMedium).copyWith(
                color: l.label.contains('commission') ? RidoColors.success : RidoColors.navy900,
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(title!, style: t.h2),
                const Spacer(),
                if (subtitle != null)
                  Flexible(
                    child: Text(subtitle!, style: t.caption, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ),
        for (final l in lines) ...[if (l.emphasis) const Divider(height: 16), row(l)],
        const Divider(height: 20),
        Row(
          children: [
            Text('Total', style: t.bodySemibold),
            const Spacer(),
            Text(formatInr(total), style: RidoTextStyles.tabular(t.h1)),
          ],
        ),
        if (footer != null) ...[const SizedBox(height: 12), footer!],
      ],
    );
  }
}
