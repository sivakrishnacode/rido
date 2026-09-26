import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../state/passenger_session.dart';

/// P-24b Add emergency contact (sheet): name, mobile number and relation. Pops with the new contact.
class P24bAddContactSheet extends ConsumerStatefulWidget {
  const P24bAddContactSheet({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  static const relations = ['Mother', 'Father', 'Spouse', 'Sister', 'Brother', 'Friend'];

  /// Opens the sheet. Returns the added contact, or null when closed.
  static Future<EmergencyContact?> show(BuildContext context) =>
      showRidoSheet<EmergencyContact>(context, builder: (_) => const P24bAddContactSheet());

  @override
  ConsumerState<P24bAddContactSheet> createState() => _P24bAddContactSheetState();
}

class _P24bAddContactSheetState extends ConsumerState<P24bAddContactSheet> {
  late final _name = TextEditingController(text: widget.showcase ? 'Lakshmi Raman' : '');
  late final _phone = TextEditingController(text: widget.showcase ? '94421 07365' : '');
  late String? _relation = widget.showcase ? 'Sister' : null;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String get _digits => PhoneInput.digitsOf(_phone.text);

  bool get _valid => _name.text.trim().isNotEmpty && _digits.length == 10 && _relation != null;

  Future<void> _save() async {
    setState(() => _saving = true);
    final d = _digits;
    final contact = EmergencyContact(
      id: 'ec-${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      relation: _relation!,
      phone: apiPhone(d),
    );
    final saved = await ref.read(passengerProfileProvider.notifier).addContact(contact);
    if (!mounted) return;
    if (!saved) {
      setState(() => _saving = false);
      return;
    }
    if (widget.showcase) {
      setState(() => _saving = false);
      showRidoSnack(context, '${contact.name} added', success: true);
    } else {
      Navigator.of(context).pop(contact);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final count = ref.watch(currentProfileProvider).emergencyContacts.length;
    final position = count + 1;
    final note = switch (position) {
      >= 3 => 'This is your 3rd and last contact',
      2 => 'This is your 2nd contact. You can add 1 more after this.',
      _ => 'You can add up to 3 contacts',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text('Add emergency contact', style: t.h1)),
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Symbols.close_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        RidoTextField(
          label: 'Name',
          hint: 'Full name',
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          fieldKey: const ValueKey('contact-name'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        PhoneInput(controller: _phone, onChanged: (_) => setState(() {})),
        const SizedBox(height: 16),
        Text('Relation', style: t.bodySmallMedium.copyWith(color: RidoColors.navy700)),
        const SizedBox(height: 8),
        ChoiceChips<String>(
          options: P24bAddContactSheet.relations,
          labelOf: (x) => x,
          selected: {?_relation},
          onChanged: (x) => setState(() => _relation = x),
        ),
        const SizedBox(height: 24),
        RidoButton(
          label: 'Add contact',
          loading: _saving,
          onPressed: _valid && count < 3 ? _save : null,
        ),
        const SizedBox(height: 8),
        Text(count >= 3 ? "You've already added 3 contacts" : note,
            style: t.bodySmall.copyWith(color: RidoColors.navy500), textAlign: TextAlign.center),
      ],
    );
  }
}
