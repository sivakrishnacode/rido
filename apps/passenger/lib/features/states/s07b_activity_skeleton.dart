import 'package:flutter/material.dart';
import 'package:rido_ui/rido_ui.dart';

import '../activity/widgets/activity_header.dart';

/// S-07b Activity loading, shown on its own (Design gallery): header and tabs over
/// [S07bActivitySkeleton].
class S07bActivitySkeletonScreen extends StatelessWidget {
  const S07bActivitySkeletonScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context) => const DefaultTabController(
    length: 3,
    child: Scaffold(
      body: Column(
        children: [
          ActivityHeader(),
          Expanded(child: S07bActivitySkeleton()),
        ],
      ),
      bottomNavigationBar: ActivityShowcaseNav(),
    ),
  );
}

/// Shimmering placeholder list of trip cards, used by P-21 while trips load.
class S07bActivitySkeleton extends StatelessWidget {
  const S07bActivitySkeleton({super.key, this.count = 5});
  final int count;

  static const _titleWidths = [150.0, 130.0, 164.0, 124.0, 142.0];
  static const _dateWidths = [96.0, 122.0, 84.0, 110.0, 96.0];

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
    child: ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RidoColors.surface,
          borderRadius: RidoRadii.cardRadius,
          border: Border.all(color: RidoColors.divider),
        ),
        child: Column(
          children: [
            Row(
              children: [
                SkeletonBox(width: _dateWidths[i % 5], height: 10, radius: 5),
                const Spacer(),
                const SkeletonBox(width: 72, height: 20, radius: 10),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const SkeletonBox(width: 44, height: 44, radius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: _titleWidths[i % 5], height: 12, radius: 6),
                      const SizedBox(height: 10),
                      const SkeletonBox(width: 78, height: 10, radius: 5),
                    ],
                  ),
                ),
                const SkeletonBox(width: 40, height: 14, radius: 7),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
