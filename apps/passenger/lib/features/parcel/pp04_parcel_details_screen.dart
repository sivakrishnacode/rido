import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../router/routes.dart';
import '../../state/parcel_flow.dart';
import 'widgets/parcel_widgets.dart';

/// PP-04 Parcel details (optional, from "What are you sending?" on PP-06): category, weight and a photo. Save → back
/// to PP-06, where the weight decides which vehicles fit.
class PP04ParcelDetailsScreen extends ConsumerWidget {
  const PP04ParcelDetailsScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final s = ref.watch(parcelFlowProvider);
    final ctrl = ref.read(parcelFlowProvider.notifier);
    final d = s.details;

    return Scaffold(
      backgroundColor: TtColors.surface,
      appBar: const TtAppBar(title: 'Parcel details'),
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
                    iconOf: parcelCategoryIcon,
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
                  PhotoAttachmentTile(
                    photo: ctrl.photo,
                    label: 'Add photo of parcel',
                    onChanged: ctrl.setPhoto,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Helps the driver come with the right vehicle and handle it with care.',
                    style: t.caption.copyWith(color: TtColors.navy500),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TtButton(
                label: 'Save',
                onPressed: () {
                  ctrl.markDetailsSet();
                  if (context.canPop()) return context.pop();
                  context.go(Routes.parcelReview);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
