import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../state/live_helpers.dart';
import 'account_providers.dart';
import 'widgets/edit_form_scaffold.dart';

/// Account › Emergency contact: who gets your live location when you press SOS. Save → back.
class DriverEmergencyContactScreen extends ConsumerStatefulWidget {
  const DriverEmergencyContactScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<DriverEmergencyContactScreen> createState() => _DriverEmergencyContactScreenState();
}

class _DriverEmergencyContactScreenState extends ConsumerState<DriverEmergencyContactScreen> {
  final _name = TextEditingController();
  final _relation = TextEditingController();
  final _phone = TextEditingController();
  EmergencyContact? _contact;
  bool _saving = false;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    ref.read(driverRepositoryProvider).emergencyContact().then((c) {
      if (!mounted) return;
      if (c.name.isEmpty && c.phone.isEmpty) {
        setState(() => _contact = c);
        return;
      }
      setState(() {
        _contact = c;
        // Sign-up saved only the number: the driver names the contact here.
        _name.text = isSignupContact(c) ? '' : c.name;
        _relation.text = c.relation;
        _phone.text = c.phone.replaceFirst(RegExp(r'^\+91\s?'), '');
      });
    }, onError: (Object e) {
      if (!mounted) return;
      setState(() => _contact = const EmergencyContact(id: '', name: '', relation: '', phone: ''));
      if (e is Exception) showTtSnack(context, userMessage(e));
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _relation.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _phoneOk => RegExp(r'^[6-9]\d{9}$').hasMatch(_phone.text.replaceAll(RegExp(r'\D'), ''));

  Future<void> _save() async {
    setState(() => _tried = true);
    if (_name.text.trim().isEmpty || !_phoneOk) return;
    setState(() => _saving = true);
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    final live = ref.read(isLiveApiProvider);
    final updated = (_contact ?? const EmergencyContact(id: 'dec-1', name: '', relation: '', phone: '')).copyWith(
      name: _name.text.trim(),
      // The API needs a relation and a phone without spaces.
      relation: _relation.text.trim().isEmpty && live ? 'Family' : _relation.text.trim(),
      phone: live ? apiPhone(digits) : '+91 ${digits.substring(0, 5)} ${digits.substring(5)}',
    );
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await ref.read(driverRepositoryProvider).updateEmergencyContact(updated);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showTtSnack(context, userMessage(e));
      return;
    }
    container.invalidate(driverEmergencyContactProvider);
    if (!mounted) return;
    showTtSnack(context, 'Emergency contact saved', success: true);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return EditFormScaffold(
      title: 'Emergency contact',
      saving: _saving,
      loading: _contact == null,
      onSave: _save,
      children: [
        Text('When you press SOS, we send this person your live location.',
            style: t.body.copyWith(color: TtColors.navy700)),
        const SizedBox(height: TtSpacing.l),
        TtTextField(
          label: 'Name',
          controller: _name,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [LengthLimitingTextInputFormatter(60)],
          errorText: _tried && _name.text.trim().isEmpty ? 'Enter a name' : null,
        ),
        const SizedBox(height: TtSpacing.l),
        TtTextField(
          label: 'Relation',
          hint: 'Wife, brother, friend…',
          controller: _relation,
          inputFormatters: [LengthLimitingTextInputFormatter(30)],
        ),
        const SizedBox(height: TtSpacing.l),
        PhoneInput(controller: _phone, errorText: _tried && !_phoneOk ? 'Enter a valid 10-digit mobile number' : null),
      ],
    );
  }
}
