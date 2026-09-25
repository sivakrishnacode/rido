import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/passenger_session.dart';

/// P-05 Profile setup (first sign-in): name, optional email, gender.
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

  static const _genders = [Gender.female, Gender.male, Gender.preferNotToSay];

  @override
  void initState() {
    super.initState();
    final p = ref.read(passengerProfileProvider).value ?? Seed.priya;
    _name = TextEditingController(text: p.name);
    _email = TextEditingController(text: p.email);
    _gender = p.gender;
    // Fill in the stored profile once it loads, unless the user has started typing.
    ref.listenManual(passengerProfileProvider, (prev, next) {
      final v = next.value;
      if (v == null || _touched || !mounted) return;
      setState(() {
        _name.text = v.name;
        _email.text = v.email;
        _gender = v.gender;
      });
    });
  }

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
    await ref.read(passengerProfileProvider.notifier).setBasics(name: name, email: _email.text.trim(), gender: _gender);
    if (!mounted) return;
    setState(() => _saving = false);
    if (widget.editing) {
      showRidoSnack(context, 'Profile updated', success: true);
      if (context.canPop()) context.pop();
    } else {
      context.go(Routes.locationPermission);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final editing = widget.editing;
    return Scaffold(
      backgroundColor: RidoColors.surface,
      appBar: editing ? const RidoAppBar(title: 'Edit profile') : null,
      body: SafeArea(
        top: !editing,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(RidoSpacing.l, editing ? RidoSpacing.s : 64, RidoSpacing.l, RidoSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!editing) ...[
                      Text('What should we call you?', style: t.display),
                      const SizedBox(height: RidoSpacing.s),
                      Text('Your driver will see your first name.', style: t.body.copyWith(color: RidoColors.navy700)),
                      const SizedBox(height: RidoSpacing.xxl),
                    ],
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
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.s, RidoSpacing.l, RidoSpacing.l),
              child: RidoButton(
                label: editing ? 'Save' : 'Continue',
                loading: _saving,
                onPressed: _name.text.trim().isEmpty ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
