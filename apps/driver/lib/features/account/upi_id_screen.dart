import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../state/driver_account.dart';
import '../../state/live_helpers.dart';
import 'widgets/edit_form_scaffold.dart';

/// Account › UPI ID: where passengers pay you (shown on the D-19 QR). Save → back. The field waits for the real
/// profile (spinner, then Retry if it can't load); Save never writes made-up details over the driver.
class UpiIdScreen extends ConsumerStatefulWidget {
  const UpiIdScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<UpiIdScreen> createState() => _UpiIdScreenState();
}

class _UpiIdScreenState extends ConsumerState<UpiIdScreen> {
  final _upi = TextEditingController();
  bool _filled = false;
  bool _saving = false;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    final p = widget.showcase ? Seed.karthik : ref.read(driverProfileProvider).value;
    if (p != null) _fill(p);
  }

  void _fill(DriverProfile p) {
    _filled = true;
    _upi.text = p.upiId;
  }

  @override
  void dispose() {
    _upi.dispose();
    super.dispose();
  }

  bool get _ok => kUpiPattern.hasMatch(_upi.text.trim());

  Future<void> _save() async {
    setState(() => _tried = true);
    if (!_ok) return;
    if (widget.showcase) {
      showTtSnack(context, 'Design preview: nothing is saved');
      return;
    }
    final p = ref.read(driverProfileProvider).value;
    if (p == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(driverProfileProvider.notifier).save(p.copyWith(upiId: _upi.text.trim()));
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showTtSnack(context, userMessage(e));
      return;
    }
    if (!mounted) return;
    showTtSnack(context, 'UPI ID updated', success: true);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final profile = widget.showcase ? const AsyncData(Seed.karthik) : ref.watch(driverProfileProvider);
    if (!_filled && profile.value != null) _fill(profile.value!);
    return EditFormScaffold(
      title: 'UPI ID',
      saving: _saving,
      loading: !_filled,
      error: !_filled && profile.hasError ? profile.error : null,
      what: 'your UPI ID',
      onRetry: () => ref.invalidate(driverProfileProvider),
      onSave: _filled ? _save : null,
      children: [
        Text('Passengers pay you directly on this UPI ID, straight to your bank. It also makes your payment QR.',
            style: t.body.copyWith(color: TtColors.navy700)),
        const SizedBox(height: TtSpacing.l),
        TtTextField(
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
