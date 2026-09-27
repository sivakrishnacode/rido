import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../../router/routes.dart';
import '../../../state/driver_account.dart';
import 'signup_widgets.dart';

/// D-07 profile photo riders see. Available once the identity check is approved (the photo is matched to the
/// verified selfie). Shows the photo, "being checked", or the admin's reason, with Take / Retake.
class ProfilePhotoCard extends ConsumerWidget {
  const ProfilePhotoCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final profile = ref.watch(driverProfileProvider).value;
    final identity = ref.watch(identityProvider).value;
    if (profile == null || identity == null || !identity.isEnabled) return const SizedBox.shrink();
    final isLocked = !identity.isApproved;
    final hasPhoto = profile.photoPath != null;
    final rejected = profile.photoRejectReason != null && !hasPhoto && !profile.hasPendingPhoto;
    final subtitle = isLocked
        ? 'Available after your licence, Aadhaar and selfie are verified'
        : profile.hasPendingPhoto
            ? "We're checking your new photo"
            : rejected
                ? profile.photoRejectReason!
                : hasPhoto
                    ? 'Riders see this photo on their trip'
                    : 'Riders see it on their trip. Take a clear, bright photo';
    final Widget trailing = profile.hasPendingPhoto
        ? const IconPill(label: 'In review', icon: Symbols.schedule_rounded, bg: RidoColors.warningTint, fg: RidoColors.warningText)
        : Material(
            color: isLocked ? RidoColors.inputBg : RidoColors.coral600,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: isLocked ? null : () => context.push(Routes.profilePhoto),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Symbols.photo_camera_rounded, color: isLocked ? RidoColors.navy500 : Colors.white, size: 20),
                    const SizedBox(width: 6),
                    Text(hasPhoto || rejected ? 'Retake' : 'Take photo',
                        style: t.button.copyWith(color: isLocked ? RidoColors.navy500 : Colors.white)),
                  ]),
                ),
              ),
            ),
          );
    return Container(
      padding: const EdgeInsets.all(RidoSpacing.l),
      decoration: BoxDecoration(
        color: RidoColors.surface,
        borderRadius: RidoRadii.cardRadius,
        border: Border.all(color: rejected ? RidoColors.error : RidoColors.divider),
      ),
      child: Row(children: [
        DriverAvatar(driver: profile, size: 44, tone: AvatarTone.navy),
        const SizedBox(width: RidoSpacing.m),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Profile photo', style: t.bodySemibold),
            Text(subtitle, style: t.bodySmall.copyWith(color: rejected ? RidoColors.error : RidoColors.navy500)),
          ]),
        ),
        const SizedBox(width: RidoSpacing.s),
        trailing,
      ]),
    );
  }
}
