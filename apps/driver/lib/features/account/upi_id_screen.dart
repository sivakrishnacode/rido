import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../state/driver_account.dart';
import 'widgets/edit_form_scaffold.dart';

/// Account › UPI ID: where passengers pay you (shown on the D-19 QR). Save → back.
class UpiIdScreen extends ConsumerStatefulWidget {
  const UpiIdScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<UpiIdScreen> createState() => _UpiIdScreenState();
}

class _UpiIdScreenState extends ConsumerState<UpiIdScreen> {
  late final _upi = TextEditingController(text: (ref.read(driverProfileProvider).value ?? Seed.karthik).upiId);
  bool _saving = false;
  bool _tried = false;

  @override
  void dispose() {
    _upi.dispose();
    super.dispose();
  }

  bool get _ok => RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$').hasMatch(_upi.text.trim());

  Future<void> _save() async {
    setState(() => _tried = true);
    if (!_ok) return;
    setState(() => _saving = true);
    final p = ref.read(driverProfileProvider).value ?? Seed.karthik;
    await ref.read(driverProfileProvider.notifier).save(p.copyWith(upiId: _upi.text.trim()));
    if (!mounted) return;
    showRidoSnack(context, 'UPI ID updated', success: true);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return EditFormScaffold(
      title: 'UPI ID',
      saving: _saving,
      onSave: _save,
      children: [
        Text('Passengers pay you directly on this UPI ID. You keep 100%.',
            style: t.body.copyWith(color: RidoColors.navy700)),
        const SizedBox(height: RidoSpacing.l),
        RidoTextField(
          label: 'UPI ID',
          hint: 'name@bank',
          controller: _upi,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Symbols.account_balance_rounded,
          errorText: _tried && !_ok ? 'Enter a valid UPI ID, like karthik@okaxis' : null,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}
