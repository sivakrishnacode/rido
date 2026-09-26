import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/flags.dart';
import '../../router/routes.dart';
import '../../state/driver_account.dart';
import '../../state/driver_session.dart';
import '../home/widgets/navy_header.dart';
import 'account_providers.dart';
import 'refer_driver_sheet.dart';

/// D-26 Driver account: profile header, Refer a driver, Documents, Vehicle details, UPI ID,
/// Emergency contact, Contribute, Help & support, Terms, Design gallery and Log out.
class D26AccountScreen extends ConsumerWidget {
  const D26AccountScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showRidoConfirm(
      context,
      title: 'Log out?',
      message: "You'll go offline. Log in again with your phone number and OTP.",
      confirmLabel: 'Log out',
      cancelLabel: 'Stay logged in',
      destructive: true,
      icon: Symbols.logout_rounded,
    );
    if (!ok || !context.mounted) return;
    await ref.read(driverSessionProvider.notifier).goOffline();
    await ref.read(driverRepositoryProvider).logout();
    if (!context.mounted) return;
    if (ref.read(isLiveApiProvider)) {
      ref.read(realtimeProvider).disconnect();
      resetDriverData(ref);
      ref.invalidate(signupProvider);
    }
    context.go(Routes.welcome);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final profile = ref.watch(driverProfileProvider).value ?? Seed.karthik;
    final kyc = ref.watch(kycProvider).value;
    final contact = ref.watch(driverEmergencyContactProvider).value;
    final verified = kyc?.where((d) => d.status == KycStatus.verified).length;
    final docsSub = kyc == null
        ? 'Driving licence, RC, insurance…'
        : verified == kyc.length
            ? 'All ${kyc.length} verified'
            : '$verified of ${kyc.length} verified';

    return Scaffold(
      backgroundColor: RidoColors.background,
      body: Column(children: [
        NavyHeader(
          padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.l, RidoSpacing.gutter, RidoSpacing.xl),
          child: Row(children: [
            RidoAvatar(initials: profile.initials, size: 76, tone: AvatarTone.dark, ringColor: RidoColors.coral500),
            const SizedBox(width: RidoSpacing.l),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(profile.name,
                        style: t.display.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: RidoSpacing.s),
                  const Icon(Symbols.star_rounded, fill: 1, color: RidoColors.warning, size: 20),
                  Text(profile.rating.toStringAsFixed(1), style: t.bodySemibold.copyWith(color: Colors.white)),
                ]),
                const SizedBox(height: RidoSpacing.xs),
                Row(children: [
                  Text('${profile.vehicleKind.label} · ', style: t.body.copyWith(color: Colors.white70)),
                  Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: NumberPlate(plate: profile.plate))),
                ]),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.l, RidoSpacing.gutter, RidoSpacing.xl),
            children: [
              RidoCard(
                color: RidoColors.coral50,
                borderColor: RidoColors.coral100,
                onTap: () => ReferDriverSheet.show(context),
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: RidoColors.coral600, shape: BoxShape.circle),
                    child: const Icon(Symbols.group_add_rounded, color: Colors.white, fill: 1),
                  ),
                  const SizedBox(width: RidoSpacing.l),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Refer a driver', style: t.h2),
                      Text('Invite drivers you know · Code ${Seed.referralCode}', style: t.bodySmall),
                    ]),
                  ),
                  const Icon(Symbols.chevron_right_rounded, color: RidoColors.coral600),
                ]),
              ),
              const SizedBox(height: RidoSpacing.m),
              RidoListGroup(children: [
                RidoListTile(
                  icon: Symbols.folder_shared_rounded,
                  title: 'Documents',
                  subtitle: docsSub,
                  onTap: () => context.push(Routes.accountDocuments),
                ),
                RidoListTile(
                  icon: profile.vehicleKind.icon,
                  title: 'Vehicle details',
                  subtitle: profile.vehicleLabel,
                  onTap: () => context.push(Routes.vehicleDetails),
                ),
                RidoListTile(
                  icon: Symbols.account_balance_rounded,
                  title: 'UPI ID',
                  subtitle: profile.upiId,
                  onTap: () => context.push(Routes.upiId),
                ),
                RidoListTile(
                  icon: Symbols.contact_emergency_rounded,
                  title: 'Emergency contact',
                  subtitle: contact == null
                      ? 'Loading…'
                      : contact.name.isEmpty
                          ? 'Add someone to alert in an emergency'
                          : contact.relation.isEmpty
                              ? contact.name.split(' ').first
                              : '${contact.name.split(' ').first} (${contact.relation})',
                  onTap: () => context.push(Routes.emergencyContact),
                ),
                RidoListTile(
                  icon: Symbols.volunteer_activism_rounded,
                  title: 'Contribute',
                  subtitle: 'Rido is free. Help keep it running',
                  onTap: () => context.push(Routes.contribute),
                ),
                RidoListTile(
                  icon: Symbols.support_agent_rounded,
                  title: 'Help & support',
                  subtitle: 'Chat, call, tickets',
                  onTap: () => context.push(Routes.help),
                ),
                RidoListTile(
                  icon: Symbols.policy_rounded,
                  title: 'Terms',
                  subtitle: 'Driver terms & privacy',
                  onTap: () => context.push(Routes.legal('terms')),
                ),
                if (kShowDesignGallery)
                  RidoListTile(
                    icon: Symbols.palette_rounded,
                    title: 'Design gallery',
                    subtitle: 'Every screen and demo controls',
                    onTap: () => context.push(Routes.gallery),
                  ),
              ]),
              const SizedBox(height: RidoSpacing.m),
              RidoListGroup(children: [
                RidoListTile(
                  icon: Symbols.logout_rounded,
                  title: 'Log out',
                  destructive: true,
                  showChevron: false,
                  onTap: () => _logout(context, ref),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}
