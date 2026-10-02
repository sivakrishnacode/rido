import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../common/flags.dart';
import '../../router/routes.dart';
import '../../state/booking_prefs.dart';
import '../../state/driver_account.dart';
import '../home/widgets/navy_header.dart';
import 'account_providers.dart';
import 'refer_driver_sheet.dart';

/// D-26 Driver account: profile header, Refer a driver, Documents, Vehicle details, UPI ID,
/// Emergency contact, Contribute, Help & support, Terms, Design gallery and Log out.
class D26AccountScreen extends ConsumerStatefulWidget {
  const D26AccountScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D26AccountScreen> createState() => _D26AccountScreenState();
}

/// What D-26 is doing to leave the account (the rows show a spinner and can't be tapped twice).
enum _Leaving { none, logout }

class _D26AccountScreenState extends ConsumerState<D26AccountScreen> {
  _Leaving _leaving = _Leaving.none;

  Future<void> _logout() async {
    if (_leaving != _Leaving.none) return;
    final ok = await showTtConfirm(
      context,
      title: 'Log out?',
      message: "You'll go offline. Log in again with your phone number and OTP.",
      confirmLabel: 'Log out',
      cancelLabel: 'Stay logged in',
      destructive: true,
      icon: Symbols.logout_rounded,
    );
    if (!ok || !mounted) return;
    setState(() => _leaving = _Leaving.logout);
    await signOutDriver(ref);
    if (mounted) context.go(Routes.welcome);
  }

  static const _spinner = SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: TtColors.error));

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final profile = ref.watch(driverProfileProvider).value ?? Seed.karthik;
    final contact = ref.watch(driverEmergencyContactProvider).value;
    final prefs = ref.watch(bookingPrefsProvider).value;
    final prefsSub = prefs == null || !prefs.hasFilters ? 'Every request · voice, Go To, Stay In, parcels' : _cap(prefs.summary);
    // Counted as Account › Documents (D-07 read-only) counts them: the uploads plus the identity check, from the
    // same source (mock: every upload verified). It used to count every KYC record and skip the identity step.
    final kyc = ref.watch(isLiveApiProvider) ? ref.watch(kycProvider).value : Seed.kycAllVerified;
    final identity = ref.watch(identityProvider).value;
    final uploads = kyc?.where((d) => driverUploadDocs.contains(d.type)).toList();
    final steps = (uploads?.length ?? 0) + (identity?.isEnabled == true ? 1 : 0);
    final verified = (uploads?.where((d) => d.status == KycStatus.verified).length ?? 0) +
        (identity?.isApproved == true ? 1 : 0);
    final docsSub = uploads == null
        ? 'Driving licence, RC, insurance…'
        : verified == steps
            ? 'All $steps verified'
            : '$verified of $steps verified';

    return Scaffold(
      backgroundColor: TtColors.background,
      body: Column(children: [
        NavyHeader(
          padding: const EdgeInsets.fromLTRB(TtSpacing.gutter, TtSpacing.l, TtSpacing.gutter, TtSpacing.xl),
          child: Row(children: [
            DriverAvatar(driver: profile, size: 76, tone: AvatarTone.dark, ringColor: TtColors.coral500),
            const SizedBox(width: TtSpacing.l),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(profile.name,
                        style: t.display.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: TtSpacing.s),
                  const Icon(Symbols.star_rounded, fill: 1, color: TtColors.warning, size: 20),
                  Text(profile.rating.toStringAsFixed(1), style: t.bodySemibold.copyWith(color: Colors.white)),
                ]),
                const SizedBox(height: TtSpacing.xs),
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
            padding: const EdgeInsets.fromLTRB(TtSpacing.gutter, TtSpacing.l, TtSpacing.gutter, TtSpacing.xl),
            children: [
              TtCard(
                color: TtColors.coral50,
                borderColor: TtColors.coral100,
                onTap: () => ReferDriverSheet.show(context),
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: TtColors.coral600, shape: BoxShape.circle),
                    child: const Icon(Symbols.group_add_rounded, color: Colors.white, fill: 1),
                  ),
                  const SizedBox(width: TtSpacing.l),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Refer a driver', style: t.h2),
                      Text('Invite drivers you know · Code ${Seed.referralCode}', style: t.bodySmall),
                    ]),
                  ),
                  const Icon(Symbols.chevron_right_rounded, color: TtColors.coral600),
                ]),
              ),
              const SizedBox(height: TtSpacing.m),
              TtListGroup(children: [
                TtListTile(
                  icon: Symbols.folder_shared_rounded,
                  title: 'Documents',
                  subtitle: docsSub,
                  onTap: () => context.push(Routes.accountDocuments),
                ),
                TtListTile(
                  icon: profile.vehicleKind.icon,
                  title: 'Vehicle details',
                  subtitle: profile.vehicleLabel,
                  onTap: () => context.push(Routes.vehicleDetails),
                ),
                TtListTile(
                  icon: Symbols.tune_rounded,
                  title: 'Booking preferences',
                  subtitle: prefsSub,
                  onTap: () => context.push(Routes.bookingPreferences),
                ),
                TtListTile(
                  icon: Symbols.account_balance_rounded,
                  title: 'UPI ID',
                  subtitle: profile.upiId,
                  onTap: () => context.push(Routes.upiId),
                ),
                TtListTile(
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
                TtListTile(
                  icon: Symbols.volunteer_activism_rounded,
                  title: 'Contribute',
                  subtitle: 'Tamil Taxi is free. Help keep it running',
                  onTap: () => context.push(Routes.contribute),
                ),
                TtListTile(
                  icon: Symbols.support_agent_rounded,
                  title: 'Help & support',
                  subtitle: 'Chat, call, tickets',
                  onTap: () => context.push(Routes.help),
                ),
                TtListTile(
                  icon: Symbols.policy_rounded,
                  title: 'Terms',
                  subtitle: 'Driver terms & privacy',
                  onTap: () => context.push(Routes.legal('terms')),
                ),
                if (kShowDesignGallery)
                  TtListTile(
                    icon: Symbols.palette_rounded,
                    title: 'Design gallery',
                    subtitle: 'Every screen and demo controls',
                    onTap: () => context.push(Routes.gallery),
                  ),
              ]),
              const SizedBox(height: TtSpacing.m),
              TtListGroup(children: [
                TtListTile(
                  icon: Symbols.logout_rounded,
                  title: _leaving == _Leaving.logout ? 'Logging out…' : 'Log out',
                  destructive: true,
                  showChevron: false,
                  trailing: _leaving == _Leaving.logout ? _spinner : null,
                  onTap: _leaving == _Leaving.none ? _logout : null,
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
