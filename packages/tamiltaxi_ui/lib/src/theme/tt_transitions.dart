import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Tamil Taxi's page transition (both apps, every route): the new screen slides in a little from the right while it
/// fades in, the screen underneath eases a little to the left; a full-screen dialog (fullscreenDialog) rises from
/// below instead. Short and calm (320 ms in, 260 ms back), so moving through a booking feels connected without
/// slowing anyone down.
class TtPageTransitionsBuilder extends PageTransitionsBuilder {
  const TtPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final fade = CurvedAnimation(parent: animation, curve: const Interval(0, 0.7, curve: Curves.easeOut));
    final from = route.fullscreenDialog ? const Offset(0, 0.06) : const Offset(0.08, 0);
    Widget page = FadeTransition(
      opacity: fade,
      child: SlideTransition(position: Tween(begin: from, end: Offset.zero).animate(enter), child: child),
    );
    if (!route.fullscreenDialog) {
      // The page underneath moves aside as the next one comes in (and back when it goes).
      final exit = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      page = SlideTransition(position: Tween(begin: Offset.zero, end: const Offset(-0.05, 0)).animate(exit), child: page);
    }
    return page;
  }
}

/// The theme's transitions: [TtPageTransitionsBuilder] everywhere except iOS, which keeps its swipe-back transition.
const ttPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: TtPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.linux: TtPageTransitionsBuilder(),
    TargetPlatform.windows: TtPageTransitionsBuilder(),
    TargetPlatform.fuchsia: TtPageTransitionsBuilder(),
  },
);
