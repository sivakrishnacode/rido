import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../earnings/widgets/earnings_header.dart';

/// S-15 Empty earnings: "No earnings yet this week", "Go online to start earning. You keep
/// 100%." with Go online (→ Home). In the earnings screen it is the body; with [showcase]
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
          padding: const EdgeInsets.all(RidoSpacing.gutter),
          child: EmptyState(
            illustration: const RidoIllustration(IllustrationKind.emptyEarnings, height: 180),
            title: 'No earnings yet ${periodSuffix(period)}',
            message: 'Go online to start earning. You keep 100%.',
            actionLabel: 'Go online',
            onAction: () => context.go(Routes.home),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!widget.showcase) return _body(context, widget.period);
    return Scaffold(
      backgroundColor: RidoColors.background,
      body: Column(children: [
        EarningsHeader(period: _period, onPeriod: (p) => setState(() => _period = p), total: 0),
        Expanded(child: _body(context, _period)),
      ]),
    );
  }
}
