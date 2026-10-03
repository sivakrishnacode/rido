import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../common/showcase.dart';
import '../../router/routes.dart';
import '../earnings/widgets/earnings_header.dart';

/// S-15 Empty earnings: "No earnings yet this week", "Go online to take rides…" with Go online
/// (→ Home). In the earnings screen it is the body; with [showcase]
/// it renders inside the earnings layout (navy header + tabs) like the design frame.
class S15EmptyEarningsView extends StatefulWidget {
  const S15EmptyEarningsView({super.key, this.showcase = false, this.period = EarningsPeriod.week});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  /// Wording follows the selected tab ("this week", "today", "this month").
  final EarningsPeriod period;

  @override
  State<S15EmptyEarningsView> createState() => _S15EmptyEarningsViewState();
}

class _S15EmptyEarningsViewState extends State<S15EmptyEarningsView> {
  late EarningsPeriod _period = widget.period;

  Widget _body(BuildContext context, EarningsPeriod period) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TtSpacing.gutter),
          child: EmptyState(
            illustration: const TtIllustration(IllustrationKind.emptyEarnings, height: 180),
            title: 'No earnings yet ${periodSuffix(period)}',
            message: 'Go online to take rides. Your trips and fares will show up here.',
            actionLabel: 'Go online',
            onAction: unlessShowcase(context, widget.showcase, () => context.go(Routes.home)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!widget.showcase) return _body(context, widget.period);
    return Scaffold(
      backgroundColor: TtColors.background,
      body: Column(children: [
        EarningsHeader(period: _period, onPeriod: (p) => setState(() => _period = p), total: 0),
        Expanded(child: _body(context, _period)),
      ]),
    );
  }
}
