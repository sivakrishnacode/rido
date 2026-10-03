import 'package:flutter/material.dart';

import '../theme/tt_colors.dart';
import '../theme/tt_tokens.dart';

enum AvatarTone { coral, navy, dark }

/// Circle avatar: [image] when given (a driver's verified photo), else initials. [online] adds a green dot.
class TtAvatar extends StatelessWidget {
  const TtAvatar({
    super.key,
    required this.initials,
    this.size = 48,
    this.tone = AvatarTone.coral,
    this.online = false,
    this.ringColor,
    this.image,
  });

  final String initials;
  final double size;
  final AvatarTone tone;
  final bool online;

  /// Optional 3px ring (driver header uses green when online).
  final Color? ringColor;

  /// Photo shown instead of the initials (falls back to them while loading or if it fails).
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      AvatarTone.coral => (TtColors.coral50, TtColors.coral600),
      AvatarTone.navy => (TtColors.inputBg, TtColors.navy900),
      AvatarTone.dark => (TtColors.navy700, Colors.white),
    };
    final label = Text(
      initials,
      style: context.type.bodySemibold.copyWith(color: fg, fontSize: size * 0.32, height: 1),
    );
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
            clipBehavior: Clip.antiAlias,
            // The photo sits inside the ring: clipped to its own circle, else its square corners cover the ring
            // and the ring shows only at the top, bottom and sides.
            child: image == null
                ? label
                : ClipOval(
                    child: Image(
                      image: image!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      frameBuilder: (_, child, frame, wasSync) => frame == null && !wasSync ? label : child,
                      errorBuilder: (_, _, _) => label,
                    ),
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
                  color: TtColors.success,
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
