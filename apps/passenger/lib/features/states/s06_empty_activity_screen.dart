import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../activity/widgets/activity_header.dart';
import 'widgets/state_orb.dart';

/// S-06 Empty activity, shown on its own (Design gallery): the Activity header and tabs over
/// [S06EmptyActivityView].
class S06EmptyActivityScreen extends StatelessWidget {
  const S06EmptyActivityScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: activityTabs.length,
        child: Scaffold(
          body: Column(
            children: [
              const ActivityHeader(),
              Expanded(child: S06EmptyActivityView(onBookRide: () => context.go(Routes.ride))),
            ],
          ),
          bottomNavigationBar: const ActivityShowcaseNav(),
        ),
      );
}

/// The S-06 body used by P-21 when there are no trips: "No trips yet" and "Book a ride".
class S06EmptyActivityView extends StatelessWidget {
  const S06EmptyActivityView({super.key, this.onBookRide, this.title = 'No trips yet'});

  /// Defaults to going to the Ride tab.
  final VoidCallback? onBookRide;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight.isFinite ? c.maxHeight : 0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const StateOrb(
                  size: 180,
                  label: 'An empty trip list',
                  child: _EmptyListCard(),
                ),
                const SizedBox(height: 24),
                Text(title, style: t.display, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text('Your rides and parcels will show here',
                    style: t.body.copyWith(color: RidoColors.navy700, fontSize: 17), textAlign: TextAlign.center),
                const SizedBox(height: 28),
                RidoButton(
                  label: 'Book a ride',
                  expand: false,
                  onPressed: onBookRide ?? () => context.go(Routes.ride),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White "receipt" card with grey lines and a coral bike badge.
class _EmptyListCard extends StatelessWidget {
  const _EmptyListCard();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 124,
        height: 132,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 96,
              height: 120,
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
              decoration: BoxDecoration(
                color: RidoColors.surface,
                borderRadius: RidoRadii.cardRadius,
                boxShadow: RidoShadows.soft,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line(68, RidoColors.coral100),
                  _line(48, RidoColors.divider),
                  _line(58, RidoColors.divider),
                  _line(34, RidoColors.divider),
                ],
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: RidoColors.coral500,
                  shape: BoxShape.circle,
                  border: Border.all(color: RidoColors.surface, width: 3),
                ),
                child: const Icon(Symbols.two_wheeler_rounded, fill: 1, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      );

  Widget _line(double w, Color c) => Container(
        width: w,
        height: 7,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: c, borderRadius: RidoRadii.pillRadius),
      );
}
