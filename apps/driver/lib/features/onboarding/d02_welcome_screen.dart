import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../router/routes.dart';
import 'widgets/signup_widgets.dart';

/// D-02 Welcome: happy-driver illustration, "Keep 100% of what you earn", three benefits,
/// "Join as a driver" (sign-up) and "Already registered? Log in".
class D02WelcomeScreen extends StatelessWidget {
  const D02WelcomeScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final h = MediaQuery.sizeOf(context).height;
    final headerH = (h * 0.42).clamp(300.0, 380.0);
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
                child: SizedBox(
                  height: headerH - MediaQuery.paddingOf(context).top.clamp(0, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(TtSpacing.l, TtSpacing.m, TtSpacing.l, 0),
                        child: Row(
                          children: [
                            DriverWordmark(size: 28, stacked: false),
                            SizedBox(width: TtSpacing.s),
                            DriverTag(),
                          ],
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) => Center(child: _HappyDriver(size: (c.maxHeight - 16).clamp(120.0, 220.0))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(TtSpacing.l, TtSpacing.xl, TtSpacing.l, TtSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Keep 100% of what you earn', style: t.display),
                    const SizedBox(height: TtSpacing.l),
                    const _Benefit(icon: Symbols.percent_rounded, text: '0% commission on every ride'),
                    const _Benefit(icon: Symbols.money_off_rounded, text: 'No subscription or monthly fee'),
                    const _Benefit(icon: Symbols.redeem_rounded, text: 'Free to use, always'),
                  ],
                ),
              ),
            ),
            BottomActions(
              children: [
                TtButton(label: 'Join as a driver', onPressed: () => context.push(Routes.phone(signup: true))),
                const SizedBox(height: TtSpacing.xs),
                Semantics(
                  button: true,
                  label: 'Already registered? Log in',
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: TtRadii.pillRadius,
                    onTap: () => context.push(Routes.phone(signup: false)),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Center(
                        child: Text.rich(
                          TextSpan(
                            text: 'Already registered? ',
                            style: t.body.copyWith(color: TtColors.navy700),
                            children: [
                              TextSpan(
                                text: 'Log in',
                                style: t.body.copyWith(color: TtColors.coral600, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: TtSpacing.s),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: TtColors.coral50, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: TtColors.coral600),
            ),
            const SizedBox(width: TtSpacing.l),
            Expanded(child: Text(text, style: context.type.body)),
          ],
        ),
      );
}

/// Smiling driver orb with a "100%" earnings chip and a small coral bike.
class _HappyDriver extends StatelessWidget {
  const _HappyDriver({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      image: true,
      label: 'A happy driver who keeps 100% of fares',
      child: SizedBox(
        width: size * 1.6,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            DriverOrb(
              size: size,
              color: TtColors.coral500,
              innerFactor: 0.73,
              child: Container(
                width: size * 0.45,
                height: size * 0.45,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Symbols.sentiment_very_satisfied_rounded, size: size * 0.36, color: TtColors.coral500),
              ),
            ),
            Positioned(
              top: size * 0.1,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: TtRadii.pillRadius),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Symbols.payments_rounded, color: TtColors.success, size: 22),
                    const SizedBox(width: 6),
                    Text('100%', style: t.h2.copyWith(color: TtColors.success)),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: size * 0.02,
              left: size * 0.12,
              child: const VehicleArt(VehicleKind.bike, size: 48),
            ),
          ],
        ),
      ),
    );
  }
}
