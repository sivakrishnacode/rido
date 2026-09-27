import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';

import 'rido_avatar.dart';

/// A driver's verified photo (the approved Didit selfie), or their initials until there is one.
class DriverAvatar extends ConsumerWidget {
  const DriverAvatar({
    super.key,
    required this.driver,
    this.size = 48,
    this.tone = AvatarTone.navy,
    this.online = false,
    this.ringColor,
  });

  final DriverProfile driver;
  final double size;
  final AvatarTone tone;
  final bool online;
  final Color? ringColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
        image: driver.photoPath != null,
        label: driver.photoPath != null ? 'Photo of ${driver.name}' : null,
        child: RidoAvatar(
          initials: driver.initials,
          size: size,
          tone: tone,
          online: online,
          ringColor: ringColor,
          image: ref.watch(driverPhotoProvider(driver.photoPath)),
        ),
      );
}
