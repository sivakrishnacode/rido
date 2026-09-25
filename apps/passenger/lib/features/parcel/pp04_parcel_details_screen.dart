import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/parcel_flow.dart';
import 'pp05_prohibited_items_sheet.dart';
import 'widgets/parcel_widgets.dart';

/// PP-04 Parcel details: category, weight, optional photo, prohibited-items check.
class PP04ParcelDetailsScreen extends ConsumerWidget {
  const PP04ParcelDetailsScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  static IconData _categoryIcon(ParcelCategory c) => switch (c) {
        ParcelCategory.documents => Symbols.description_rounded,
        ParcelCategory.food => Symbols.lunch_dining_rounded,
        ParcelCategory.clothes => Symbols.checkroom_rounded,
        ParcelCategory.electronics => Symbols.devices_rounded,
        ParcelCategory.household => Symbols.weekend_rounded,
        ParcelCategory.furniture => Symbols.bed_rounded,
        ParcelCategory.other => Symbols.more_horiz_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final s = ref.watch(parcelFlowProvider);
    final ctrl = ref.read(parcelFlowProvider.notifier);
    final d = s.details;

    return Scaffold(
      backgroundColor: RidoColors.surface,
      appBar: const ParcelStepAppBar(title: 'Parcel details', step: 3),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('What are you sending?', style: t.h2),
                  const SizedBox(height: 12),
                  ChoiceChips<ParcelCategory>(
                    options: ParcelCategory.values,
                    labelOf: (c) => c.label,
                    iconOf: _categoryIcon,
                    selected: {d.category},
                    onChanged: (c) => ctrl.updateDetails(d.copyWith(category: c)),
                  ),
                  const SizedBox(height: 24),
                  Text('Approximate weight', style: t.h2),
                  const SizedBox(height: 12),
                  ChoiceChips<WeightBand>(
                    options: WeightBand.values,
                    labelOf: (w) => w.label,
                    selected: {d.weight},
                    onChanged: (w) => ctrl.updateDetails(d.copyWith(weight: w)),
                  ),
                  const SizedBox(height: 24),
                  _PhotoTile(
                    added: d.hasPhoto,
                    onTap: () {
                      ctrl.updateDetails(d.copyWith(hasPhoto: !d.hasPhoto));
                      showRidoSnack(context, d.hasPhoto ? 'Photo removed' : 'Photo added', success: !d.hasPhoto);
                    },
                  ),
                  const SizedBox(height: 16),
                  _ProhibitedCheck(
                    value: s.noProhibitedItems,
                    onChanged: (v) => ctrl.setNoProhibitedItems(v),
                    onSeeList: () => PP05ProhibitedItemsSheet.show(context),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: RidoButton(
                label: 'Continue',
                onPressed: s.noProhibitedItems ? () => context.push(Routes.parcelReview) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.added, required this.onTap});
  final bool added;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      button: true,
      label: added ? 'Photo added. Tap to remove' : 'Add photo of parcel, optional',
      excludeSemantics: true,
      child: Material(
        color: added ? RidoColors.successTint : RidoColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: RidoRadii.cardRadius,
          side: BorderSide(color: added ? RidoColors.success : RidoColors.navy300),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: RidoColors.surface,
                    borderRadius: RidoRadii.cardRadius,
                    border: Border.all(color: RidoColors.divider),
                  ),
                  child: Icon(
                    added ? Symbols.image_rounded : Symbols.add_a_photo_rounded,
                    color: added ? RidoColors.success : RidoColors.coral600,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(added ? 'Photo added ✓' : 'Add photo of parcel',
                          style: t.bodySemibold.copyWith(color: added ? RidoColors.successText : RidoColors.navy900)),
                      const SizedBox(height: 2),
                      Text(
                        added ? 'parcel_photo.jpg · Tap to remove' : 'Optional · helps the driver pick the right vehicle',
                        style: t.bodySmall.copyWith(color: RidoColors.navy500),
                      ),
                    ],
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

class _ProhibitedCheck extends StatelessWidget {
  const _ProhibitedCheck({required this.value, required this.onChanged, required this.onSeeList});
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onSeeList;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return RidoCard(
      onTap: () => onChanged(!value),
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      borderColor: value ? RidoColors.coral100 : RidoColors.divider,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            semanticLabel: 'My parcel has no prohibited items',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My parcel has no prohibited items', style: t.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Required. ', style: t.bodySmall.copyWith(color: RidoColors.navy700)),
                      TextButton(
                        onPressed: onSeeList,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(48, 40),
                          foregroundColor: RidoColors.coral600,
                          textStyle: t.bodySmall.copyWith(fontWeight: FontWeight.w600),
                        ),
                        child: const Text('See list'),
                      ),
                    ],
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
