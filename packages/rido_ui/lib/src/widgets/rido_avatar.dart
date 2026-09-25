import 'package:flutter/material.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

enum AvatarTone { coral, navy, dark }

/// Circle avatar with initials (no photos in the prototype). [online] adds a green dot.
class RidoAvatar extends StatelessWidget {
  const RidoAvatar({
    super.key,
    required this.initials,
    this.size = 48,
    this.tone = AvatarTone.coral,
    this.online = false,
    this.ringColor,
  });

  final String initials;
  final double size;
  final AvatarTone tone;
  final bool online;

  /// Optional 3px ring (driver header uses green when online).
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      AvatarTone.coral => (RidoColors.coral50, RidoColors.coral600),
      AvatarTone.navy => (RidoColors.inputBg, RidoColors.navy900),
      AvatarTone.dark => (RidoColors.navy700, Colors.white),
    };
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: ringColor != null ? Border.all(color: ringColor!, width: 3) : null,
            ),
            child: Text(
              initials,
              style: context.type.bodySemibold.copyWith(color: fg, fontSize: size * 0.32, height: 1),
            ),
          ),
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: RidoColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
