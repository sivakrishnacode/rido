import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart' show driverPlansEnabledProvider;
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../common/showcase.dart';
import '../../router/routes.dart';
import '../onboarding/widgets/signup_widgets.dart';

/// "until 3:40 PM" today, "until 3:40 PM tomorrow", else "until 3:40 PM, 30 Sep".
String pausedUntilLabel(DateTime until, DateTime now) {
  final day = DateTime(until.year, until.month, until.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = day.difference(today).inDays;
  final when = switch (days) { 0 => formatTime(until), 1 => '${formatTime(until)} tomorrow', _ => '${formatTime(until)}, ${formatShortDate(until)}' };
  return 'until $when';
}

/// S-10 Account on hold (temporary): reason and "Contact support". S-10b with [pausedUntil]: paused for too many
/// cancellations (403 `DRIVER_TEMP_BLOCKED` when going online), with the time it ends.
class S10AccountOnHoldScreen extends ConsumerWidget {
  const S10AccountOnHoldScreen({super.key, this.showcase = false, this.pausedUntil});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  /// Paused for too many cancellations until then (S-10b); null = on hold by an admin (S-10).
  final DateTime? pausedUntil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final until = pausedUntil;
    final plans = ref.watch(driverPlansEnabledProvider);
    final isPaused = until != null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: TtColors.surface,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: TtColors.navy900,
              child: SafeArea(
                bottom: false,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(TtSpacing.l, TtSpacing.xxl + 16, TtSpacing.l, TtSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            image: true,
                            label: 'Account paused',
                            child: Center(child: DriverOrb(
                              size: 160,
                              color: TtColors.warning,
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  const Icon(Symbols.pause_rounded, size: 80, color: TtColors.navy900, fill: 1),
                                  Positioned(
                                    top: -52,
                                    right: -52,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: const BoxDecoration(color: TtColors.coral500, shape: BoxShape.circle),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ),
                          const SizedBox(height: TtSpacing.xl),
                          Center(child: StatusPill(StatusKind.paused, label: isPaused ? 'Paused' : 'On hold')),
                          const SizedBox(height: TtSpacing.m),
                          Text(isPaused ? "You're paused ${pausedUntilLabel(until, DateTime.now())}" : 'Your account is on hold',
                              textAlign: TextAlign.center, style: t.display.copyWith(color: Colors.white)),
                        ],
                      ),
                    ),
                    if (Navigator.of(context).canPop())
                      Positioned(
                        left: TtSpacing.xs,
                        top: TtSpacing.s,
                        child: IconButton(
                          tooltip: 'Back',
                          icon: const Icon(Symbols.arrow_back_rounded, color: Colors.white),
                          onPressed: () => context.pop(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(TtSpacing.l),
                child: Container(
                  padding: const EdgeInsets.all(TtSpacing.l),
                  decoration: const BoxDecoration(color: TtColors.inputBg, borderRadius: TtRadii.cardRadius),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Symbols.info_rounded, color: TtColors.navy700),
                      const SizedBox(width: TtSpacing.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // The API keeps no reason for an admin's hold, so this doesn't guess one.
                            Text(isPaused ? 'Too many cancelled rides' : 'An admin has put your account on hold',
                                style: t.bodySemibold),
                            const SizedBox(height: 2),
                            Text(
                                isPaused
                                    ? 'You cancelled half or more of the rides you accepted this week. You can go online again '
                                        '${pausedUntilLabel(until, DateTime.now())}. Only accept rides you can reach; '
                                        "a passenger who doesn't come after the wait doesn't count against you."
                                    : "You can't go online until it's sorted out. Contact support to find out why and what to "
                                        "do.${plans ? ' Your plan days are paused, not lost.' : ''}",
                                style: t.bodySmall.copyWith(color: TtColors.navy700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            BottomActions(
              children: [
                TtButton(
                  label: 'Contact support',
                  icon: Symbols.support_agent_rounded,
                  onPressed: unlessShowcase(context, showcase, () => context.push(Routes.help)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
