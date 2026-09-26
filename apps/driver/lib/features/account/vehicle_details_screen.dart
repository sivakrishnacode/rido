import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../state/driver_account.dart';
import '../../state/live_helpers.dart';
import 'widgets/edit_form_scaffold.dart';

/// Account › Vehicle details: model, colour and number plate (prefilled), Save → back.
class VehicleDetailsScreen extends ConsumerStatefulWidget {
  const VehicleDetailsScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends ConsumerState<VehicleDetailsScreen> {
  late final DriverProfile _p = ref.read(driverProfileProvider).value ?? Seed.karthik;
  late final _model = TextEditingController(text: _p.vehicleModel);
  late final _color = TextEditingController(text: _p.vehicleColor);
  late final _plate = TextEditingController(text: _p.plate);
  bool _saving = false;
  bool _tried = false;

  @override
  void dispose() {
    _model.dispose();
    _color.dispose();
    _plate.dispose();
    super.dispose();
  }

  bool get _plateOk => kPlatePattern.hasMatch(_plate.text.trim());

  Future<void> _save() async {
    setState(() => _tried = true);
    if (_model.text.trim().isEmpty || !_plateOk) return;
    setState(() => _saving = true);
    final current = ref.read(driverProfileProvider).value ?? _p;
    try {
      await ref.read(driverProfileProvider.notifier).save(current.copyWith(
            vehicleModel: _model.text.trim(),
            vehicleColor: _color.text.trim(),
            plate: _plate.text.trim().toUpperCase(),
          ));
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showRidoSnack(context, userMessage(e));
      return;
    }
    if (!mounted) return;
    showRidoSnack(context, 'Vehicle details saved', success: true);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return EditFormScaffold(
      title: 'Vehicle details',
      saving: _saving,
      onSave: _save,
      children: [
        Text('Vehicle type', style: t.bodyMedium.copyWith(color: RidoColors.navy700)),
        const SizedBox(height: RidoSpacing.s),
        RidoCard(
          child: Row(children: [
            Icon(_p.vehicleKind.icon, color: RidoColors.coral600),
            const SizedBox(width: RidoSpacing.m),
            Expanded(child: Text(_p.vehicleKind.label, style: t.bodySemibold)),
            Text('Linked to your plan', style: t.caption),
          ]),
        ),
        const SizedBox(height: RidoSpacing.l),
        RidoTextField(
          label: 'Model',
          controller: _model,
          textCapitalization: TextCapitalization.words,
          errorText: _tried && _model.text.trim().isEmpty ? 'Enter the vehicle model' : null,
        ),
        const SizedBox(height: RidoSpacing.l),
        RidoTextField(label: 'Colour', controller: _color, textCapitalization: TextCapitalization.words),
        const SizedBox(height: RidoSpacing.l),
        RidoTextField(
          label: 'Number plate',
          controller: _plate,
          textCapitalization: TextCapitalization.characters,
          errorText: _tried && !_plateOk ? 'Use the format TN 37 AB 4521' : null,
        ),
        const SizedBox(height: RidoSpacing.m),
        Text('A change of vehicle may need a new RC check.', style: t.caption),
      ],
    );
  }
}
