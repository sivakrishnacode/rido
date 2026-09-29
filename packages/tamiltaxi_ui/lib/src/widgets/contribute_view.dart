import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

import '../format.dart';
import '../theme/tt_colors.dart';
import '../theme/tt_tokens.dart';
import 'choice_chips.dart';
import 'tt_button.dart';
import 'tt_card.dart';
import 'tt_dialogs.dart';
import 'section_label.dart';
import 'skeleton_box.dart';

/// Contribute page body (shared by both apps): why Tamil Taxi is free, the monthly running cost with its
/// breakdown, amount chips, a UPI pay button and a QR code. The app opens the `upi://` link in [onPay].
class ContributeView extends StatefulWidget {
  const ContributeView({super.key, required this.info, required this.onPay});

  /// Null while loading.
  final ContributeInfo? info;

  /// Opens the UPI app for [ContributeInfo.payUri] with [amountInr] (null = the payer types it).
  final ValueChanged<int?> onPay;

  static const amounts = [20, 50, 100, 200];

  @override
  State<ContributeView> createState() => _ContributeViewState();
}

class _ContributeViewState extends State<ContributeView> {
  int? _amount = 50;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final info = widget.info;
    return ListView(
      padding: const EdgeInsets.fromLTRB(TtSpacing.gutter, TtSpacing.xl, TtSpacing.gutter, TtSpacing.xl),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: TtColors.coral50, shape: BoxShape.circle),
            child: const Icon(Symbols.volunteer_activism_rounded, size: 32, color: TtColors.coral600, fill: 1),
          ),
        ),
        const SizedBox(height: TtSpacing.l),
        Text('Tamil Taxi is free', style: t.h1, textAlign: TextAlign.center),
        const SizedBox(height: TtSpacing.s),
        const Wrap(alignment: WrapAlignment.center, spacing: TtSpacing.s, runSpacing: TtSpacing.s, children: [
          _Pill(icon: Symbols.percent_rounded, label: '0% commission'),
          _Pill(icon: Symbols.money_off_rounded, label: 'No subscription'),
        ]),
        const SizedBox(height: TtSpacing.l),
        if (info == null) ...[
          const SkeletonBox(height: 48),
          const SizedBox(height: TtSpacing.l),
          const SkeletonBox(height: 160),
        ] else ...[
          Text(info.note, style: t.body.copyWith(color: TtColors.navy700), textAlign: TextAlign.center),
          if (info.monthlyCostInr != null) ...[
            const SectionLabel('What it costs to run'),
            _CostCard(total: info.monthlyCostInr!, items: info.costItems),
          ],
          if (info.canPay) ...[
            const SectionLabel('Contribute'),
            ChoiceChips<int?>(
              options: const [...ContributeView.amounts, null],
              labelOf: (a) => a == null ? 'Other amount' : formatInr(a),
              selected: {_amount},
              onChanged: (a) => setState(() => _amount = a),
            ),
            const SizedBox(height: TtSpacing.l),
            TtButton(
              label: _amount == null ? 'Contribute with UPI' : 'Contribute ${formatInr(_amount!)} with UPI',
              icon: Symbols.favorite_rounded,
              onPressed: () => widget.onPay(_amount),
            ),
            const SectionLabel('Or scan with any UPI app'),
            _QrCard(info: info),
          ] else ...[
            const SizedBox(height: TtSpacing.xl),
            Text('Contributions open soon.', style: t.bodySmall.copyWith(color: TtColors.navy500), textAlign: TextAlign.center),
          ],
          const SizedBox(height: TtSpacing.xl),
          Text('Every rupee goes to running Tamil Taxi. Thank you!', style: t.caption, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: const BoxDecoration(color: TtColors.successTint, borderRadius: TtRadii.pillRadius),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: TtColors.successText),
          const SizedBox(width: 4),
          Text(label, style: context.type.bodySmallMedium.copyWith(color: TtColors.successText)),
        ]),
      );
}

class _CostCard extends StatelessWidget {
  const _CostCard({required this.total, required this.items});
  final int total;
  final List<CostItem> items;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return TtCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('App running & infrastructure', style: t.bodySmall.copyWith(color: TtColors.navy500)),
        const SizedBox(height: TtSpacing.xs),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(formatInr(total), style: t.hero),
          const SizedBox(width: 6),
          Text('per month', style: t.bodySmall.copyWith(color: TtColors.navy500)),
        ]),
        if (items.isNotEmpty) ...[
          const SizedBox(height: TtSpacing.m),
          const Divider(height: 1),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(top: TtSpacing.m),
              child: Row(children: [
                Expanded(child: Text(i.label, style: t.body.copyWith(color: TtColors.navy700))),
                Text(formatInr(i.amountInr), style: t.bodyMedium),
              ]),
            ),
        ],
      ]),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.info});
  final ContributeInfo info;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return TtCard(
      child: Column(children: [
        QrImageView(
          // No amount in the QR: the payer chooses it in their UPI app.
          data: info.payUri().toString(),
          size: 180,
          padding: EdgeInsets.zero,
          semanticsLabel: 'UPI QR code for ${info.upiId}',
          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: TtColors.navy900),
          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: TtColors.navy900),
        ),
        const SizedBox(height: TtSpacing.m),
        Text(info.payeeName, style: t.bodySemibold),
        const SizedBox(height: 2),
        InkWell(
          borderRadius: TtRadii.pillRadius,
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: info.upiId));
            if (context.mounted) showTtSnack(context, 'UPI ID copied');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(info.upiId, style: t.bodySmall.copyWith(color: TtColors.navy700)),
              const SizedBox(width: 6),
              const Icon(Symbols.content_copy_rounded, size: 16, color: TtColors.navy500),
            ]),
          ),
        ),
      ]),
    );
  }
}
