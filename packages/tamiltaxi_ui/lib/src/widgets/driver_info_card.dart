import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

import '../theme/tt_colors.dart';
import '../theme/tt_tokens.dart';
import 'number_plate.dart';
import 'tt_avatar.dart';

/// Driver card: photo (or initials) avatar, name, rating, vehicle, Indian number plate, and
/// round chat / call buttons. [statusText] shows on the right ("2 min away", "Arrived").
class DriverInfoCard extends StatelessWidget {
  const DriverInfoCard({
    super.key,
    required this.name,
    required this.initials,
    required this.rating,
    required this.vehicle,
    required this.plate,
    this.vehicleKind,
    this.rides,
    this.statusText,
    this.statusColor = TtColors.success,
    this.onCall,
    this.onChat,
    this.bordered = true,
    this.photo,
  });

  final String name;
  final String initials;
  final double rating;

  /// "Honda Activa · Grey"
  final String vehicle;
  final String plate;

  /// Picks the plate colour (see [NumberPlate]).
  final VehicleKind? vehicleKind;

  /// Shown as "(1,240 rides)".
  final String? rides;
  final String? statusText;
  final Color statusColor;
  final VoidCallback? onCall;
  final VoidCallback? onChat;
  final bool bordered;

  /// The driver's verified photo (`driverPhotoProvider`); initials when null.
  final ImageProvider? photo;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TtColors.surface,
        borderRadius: TtRadii.cardRadius,
        border: bordered ? Border.all(color: TtColors.divider) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TtAvatar(initials: initials, size: 52, tone: AvatarTone.navy, image: photo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(name, style: t.bodySemibold.copyWith(fontSize: 17)),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Symbols.star_rounded, fill: 1, size: 18, color: TtColors.warning),
                          const SizedBox(width: 2),
                          Text(rating.toStringAsFixed(1), style: t.bodySmallMedium),
                          if (rides != null) Text(' ($rides rides)', style: t.caption),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(vehicle, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (onChat != null)
                _RoundAction(
                  icon: Symbols.chat_rounded,
                  label: 'Chat with $name',
                  onTap: onChat!,
                  filled: false,
                ),
              if (onCall != null) ...[
                const SizedBox(width: 8),
                _RoundAction(icon: Symbols.call_rounded, label: 'Call $name', onTap: onCall!, filled: true),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: NumberPlate(plate: plate, vehicle: vehicleKind),
                ),
              ),
              if (statusText != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    statusText!,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmallMedium.copyWith(color: statusColor),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.label, required this.onTap, required this.filled});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Material(
          color: filled ? TtColors.coral600 : TtColors.coral50,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(icon, fill: 1, color: filled ? Colors.white : TtColors.coral600, size: 22),
            ),
          ),
        ),
      );
}
