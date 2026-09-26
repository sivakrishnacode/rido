import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/passenger_session.dart';
import 'widgets/sign_in_step.dart';

/// P-05 Profile setup (first sign-in, step 3/3): name, optional email, gender; confetti on Continue.
/// With [editing] it is the Account "Edit profile" screen (title "Edit profile", "Save").
class P05ProfileSetupScreen extends ConsumerStatefulWidget {
  const P05ProfileSetupScreen({super.key, this.editing = false, this.showcase = false});

  final bool editing;

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<P05ProfileSetupScreen> createState() => _P05ProfileSetupScreenState();
}

class _P05ProfileSetupScreenState extends ConsumerState<P05ProfileSetupScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late Gender _gender;
  bool _touched = false;
  bool _saving = false;
  int _celebrate = 0;

  static const _genders = [Gender.female, Gender.male, Gender.preferNotToSay];

  @override
  void initState() {
    super.initState();
    final p = ref.read(currentProfileProvider);
    _name = TextEditingController(text: _realName(p.name));
    _email = TextEditingController(text: p.email);
    _gender = p.gender;
    // Fill in the stored profile once it loads, unless the user has started typing.
    ref.listenManual(passengerProfileProvider, (prev, next) {
      final v = next.value;
      if (v == null || _touched || !mounted) return;
      setState(() {
        _name.text = _realName(v.name);
        _email.text = v.email;
        _gender = v.gender;
      });
    });
  }

  /// The placeholder shown before a name is set is not a name to prefill.
  static String _realName(String name) => name == kPlaceholderName ? '' : name;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  String _label(Gender g) => switch (g) {
    Gender.female => 'Female',
    Gender.male => 'Male',
    Gender.preferNotToSay => 'Prefer not to say',
  };

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final saved = await ref
        .read(passengerProfileProvider.notifier)
        .setBasics(name: name, email: _email.text.trim(), gender: _gender);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) return;
    if (widget.editing) {
      showRidoSnack(context, 'Profile updated', success: true);
      if (context.canPop()) context.pop();
    } else {
      setState(() => _celebrate++);
      await Future<void>.delayed(ConfettiBurst.duration * 0.7);
      if (mounted) context.go(Routes.locationPermission);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final button = RidoButton(
      label: widget.editing ? 'Save' : 'Continue',
      loading: _saving,
      onPressed: _name.text.trim().isEmpty ? null : _submit,
    );
    if (!widget.editing) {
      return SignInStep(
        step: 3,
        badge: Symbols.waving_hand_rounded,
        badgeMotion: BadgeMotion.wave,
        title: 'Nice to meet you!',
        subtitle: const Text('What should we call you? Your driver will see your first name.'),
        overlay: ConfettiBurst(trigger: _celebrate, origin: const Offset(0.5, 0.85)),
        card: _fields(t),
        action: PopWhenReady(ready: _name.text.trim().isNotEmpty, child: button),
      );
    }
    return Scaffold(
      backgroundColor: RidoColors.surface,
      appBar: const RidoAppBar(title: 'Edit profile'),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.s, RidoSpacing.l, RidoSpacing.l),
                child: _fields(t),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.s, RidoSpacing.l, RidoSpacing.l),
              child: button,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fields(RidoTextStyles t) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RidoTextField(
        label: 'Full name',
        controller: _name,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        onChanged: (_) => setState(() => _touched = true),
      ),
      const SizedBox(height: RidoSpacing.xl),
      Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Email '),
            TextSpan(
              text: '(optional)',
              style: t.bodySmall.copyWith(color: RidoColors.navy500),
            ),
          ],
        ),
        style: t.bodySmallMedium.copyWith(color: RidoColors.navy700),
      ),
      const SizedBox(height: 6),
      RidoTextField(
        hint: 'For ride receipts',
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        onChanged: (_) => _touched = true,
      ),
      const SizedBox(height: RidoSpacing.xl),
      Text('Gender', style: t.bodySmallMedium.copyWith(color: RidoColors.navy700)),
      const SizedBox(height: RidoSpacing.s),
      ChoiceChips<Gender>(
        options: _genders,
        labelOf: _label,
        selected: {_gender},
        showCheck: true,
        onChanged: (g) => setState(() {
          _gender = g;
          _touched = true;
        }),
      ),
      const SizedBox(height: RidoSpacing.m),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Symbols.lock_rounded, size: 18, color: RidoColors.navy500),
          const SizedBox(width: RidoSpacing.s),
          Expanded(
            child: Text(
              'Only used to offer the "Prefer women driver" option. Never shown to drivers.',
              style: t.bodySmall.copyWith(color: RidoColors.navy500),
            ),
          ),
        ],
      ),
    ],
  );
}
