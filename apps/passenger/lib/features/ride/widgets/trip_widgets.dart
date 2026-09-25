import 'package:flutter/material.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

/// Map-over-sheet layout used by the in-trip screens (P-13, P-15, P-16, S-01, S-02):
/// the map fills the screen, [overlays] float on it and [sheet] sits at the bottom with
/// 16px rounded top corners. The sheet scrolls if it is taller than [maxSheetFraction].
class TripSheetScaffold extends StatelessWidget {
  const TripSheetScaffold({
    super.key,
    required this.map,
    required this.sheet,
    this.overlays = const [],
    this.maxSheetFraction = 0.74,
    this.appBar,
    this.aboveSheet,
  });

  /// Built with the body height, so fit padding can leave room for the sheet.
  final Widget Function(BuildContext context, double height) map;
  final Widget sheet;
  final List<Widget> overlays;
  final double maxSheetFraction;
  final PreferredSizeWidget? appBar;

  /// Floats just above the sheet's top edge, e.g. the P-16 SOS button.
  final Widget? aboveSheet;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RidoColors.inputBg,
      appBar: appBar,
      body: LayoutBuilder(
        builder: (context, c) => Stack(
          children: [
            Positioned.fill(child: map(context, c.maxHeight)),
            ...overlays,
            Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?aboveSheet,
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: c.maxHeight * maxSheetFraction),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: RidoColors.surface,
                        borderRadius: RidoRadii.sheetTop,
                        boxShadow: RidoShadows.raised,
                      ),
                      child: SafeArea(
                        top: false,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [const SheetHandle(), sheet],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back button (left) and SOS (right) floating over a trip map.
class TripMapTopBar extends StatelessWidget {
  const TripMapTopBar({super.key, required this.onBack, this.onSos});

  final VoidCallback onBack;
  final VoidCallback? onSos;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MapCircleButton(icon: Symbols.arrow_back_rounded, tooltip: 'Back', onPressed: onBack),
          const Spacer(),
          if (onSos != null) SosButton(onPressed: onSos!, size: 56),
        ],
      ),
    ),
  );
}

/// P-13 driver row: avatar, name + rating + rides, vehicle, and the number plate on the right.
class TripDriverRow extends StatelessWidget {
  const TripDriverRow({super.key, required this.driver});
  final DriverProfile driver;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Row(
      children: [
        RidoAvatar(initials: driver.initials, size: 56, tone: AvatarTone.navy),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(driver.name, style: t.bodySemibold.copyWith(fontSize: 17), maxLines: 2),
              Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(Symbols.star_rounded, fill: 1, size: 18, color: RidoColors.warning),
                    ),
                    TextSpan(
                      text: ' ${driver.rating.toStringAsFixed(1)}',
                      style: RidoTextStyles.tabular(t.bodySmallMedium),
                    ),
                    TextSpan(text: ' (${formatCount(driver.rides)} rides)', style: t.caption),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(driver.vehicleLabel, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 8),
        NumberPlate(plate: driver.plate),
      ],
    );
  }
}

/// Compact driver row (P-15, P-16): avatar, "Karthik S · 4.8★" over the number plate, and a trailing widget.
class CompactDriverRow extends StatelessWidget {
  const CompactDriverRow({super.key, required this.driver, this.trailing, this.showRating = true});
  final DriverProfile driver;
  final Widget? trailing;
  final bool showRating;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Row(
      children: [
        RidoAvatar(initials: driver.initials, size: 50, tone: AvatarTone.navy),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                showRating ? '${driver.name} · ${driver.rating.toStringAsFixed(1)}★' : driver.name,
                style: t.bodySemibold.copyWith(fontSize: 17),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: NumberPlate(plate: driver.plate),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

/// Round 48px icon button with a tinted fill (chat / call in trip sheets).
class RoundIconAction extends StatelessWidget {
  const RoundIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.background = RidoColors.coral50,
    this.foreground = RidoColors.coral600,
    this.size = 48,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, fill: 1, color: foreground, size: size * 0.46),
          ),
        ),
      ),
    ),
  );
}

/// Labelled circular action (P-13 action row: Call · Chat · Share trip · Cancel).
class TripActionButton extends StatelessWidget {
  const TripActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.caption,
    this.background = RidoColors.coral50,
    this.foreground = RidoColors.coral600,
    this.labelColor = RidoColors.navy900,
  });

  final IconData icon;
  final String label;
  final String? caption;
  final VoidCallback onPressed;
  final Color background;
  final Color foreground;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: RidoRadii.cardRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: background, shape: BoxShape.circle),
                child: Icon(icon, color: foreground, fill: 1, size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: t.bodySmallMedium.copyWith(color: labelColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (caption != null) Text(caption!, style: t.caption),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ride OTP box (P-13): label and caption on the left, big tabular digits on the right.
class RideOtpCard extends StatelessWidget {
  const RideOtpCard({super.key, required this.code, this.label = 'Ride OTP', this.caption});

  final String code;
  final String label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      label: '$label ${code.split('').join(' ')}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(
          color: RidoColors.coral50,
          borderRadius: RidoRadii.cardRadius,
          border: Border.all(color: RidoColors.coral100),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(), style: t.overline.copyWith(color: RidoColors.coral600)),
                  if (caption != null) ...[
                    const SizedBox(height: 4),
                    Text(caption!, style: t.bodySmall.copyWith(color: RidoColors.navy700)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            for (final d in code.split(''))
              Container(
                margin: const EdgeInsets.only(left: 4),
                width: 36,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: RidoColors.surface, borderRadius: BorderRadius.circular(8)),
                child: Text(d, style: t.otp),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pickup → drop with the fare on the right ("₹38 · Cash / UPI").
class TripRouteSummary extends StatelessWidget {
  const TripRouteSummary({super.key, required this.pickup, required this.drop, required this.fare});

  final String pickup;
  final String drop;
  final int fare;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Row(
      children: [
        Expanded(
          child: PickupDropConnector(pickupTitle: pickup, dropTitle: drop, dense: true),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatInr(fare), style: RidoTextStyles.tabular(t.h1)),
            Text('Cash / UPI', style: t.bodySmall.copyWith(color: RidoColors.navy500)),
          ],
        ),
      ],
    );
  }
}

/// Navy speech bubble shown above the pickup on the map ("3 min").
class EtaBubble extends StatelessWidget {
  const EtaBubble({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: const BoxDecoration(color: RidoColors.navy900, borderRadius: RidoRadii.pillRadius),
        child: Text(
          text,
          maxLines: 1,
          style: RidoTextStyles.tabular(context.type.bodySemibold.copyWith(color: Colors.white)),
        ),
      ),
      CustomPaint(size: const Size(12, 6), painter: _TailPainter()),
    ],
  );
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = RidoColors.navy900);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Short display name for trip summaries: "Gandhipuram Central Bus Stand" → "Gandhipuram",
/// "Brookefields Mall" → "Brookefields".
String shortPlaceName(String name) {
  const suffixes = [' Central Bus Stand', ' Mall', ' International Airport', ' Saravanampatti'];
  for (final s in suffixes) {
    if (name.endsWith(s)) return name.substring(0, name.length - s.length);
  }
  return name;
}

/// The part of [path] still ahead of a vehicle at [progress] (0..1), starting at [position].
List<LatLng> remainingPath(List<LatLng> path, LatLng position, double progress) {
  if (path.length < 2) return path;
  final i = (progress.clamp(0.0, 1.0) * (path.length - 1)).floor();
  return [position, ...path.sublist((i + 1).clamp(0, path.length))];
}

/// Driver start → pickup path used before the controller has built one (showcase / deep link).
List<LatLng> fallbackApproach(Place pickup) =>
    roadPath(offsetPoint(pickup.location, 900, 35), pickup.location, bend: -0.2);
