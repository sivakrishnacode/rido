import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/parcel_flow.dart';
import '../../state/passenger_session.dart';
import 'widgets/parcel_widgets.dart';

/// Sample building / floor / landmark shown on PP-02.
const _samplePickupNote = 'Flat 3B, Sri Lakshmi Apartments, near PSG Tech gate';

/// PP-02 Pickup details: pickup pin, sender name + phone, building / landmark.
class PP02PickupDetailsScreen extends ConsumerStatefulWidget {
  const PP02PickupDetailsScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<PP02PickupDetailsScreen> createState() => _PP02PickupDetailsScreenState();
}

class _PP02PickupDetailsScreenState extends ConsumerState<PP02PickupDetailsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _note;
  String? _nameError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    final d = ref.read(parcelFlowProvider).details;
    final live = ref.read(isLiveApiProvider);
    // Live API: the sender is the signed-in passenger unless they typed someone else.
    final me = ref.read(currentProfileProvider);
    final useMe = live && d.senderName.isEmpty && me.name != kPlaceholderName;
    _name = TextEditingController(text: useMe ? me.name : d.senderName);
    _phone = TextEditingController(text: localPhone(useMe ? me.phone : d.senderPhone));
    _note = TextEditingController(text: d.pickupNote.isEmpty && !live ? _samplePickupNote : d.pickupNote);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _changePlace() async {
    final current = ref.read(parcelFlowProvider).pickup;
    final p = await showParcelPlacePicker(context, title: 'Pickup from', current: current);
    if (p == null || !mounted) return;
    ref.read(parcelFlowProvider.notifier).setPickup(p);
  }

  void _confirm() {
    final name = _name.text.trim();
    final digits = phoneDigits(_phone.text);
    setState(() {
      _nameError = name.isEmpty ? 'Enter the sender’s name' : null;
      _phoneError = digits.length != 10 ? 'Enter a 10-digit mobile number' : null;
    });
    if (_nameError != null || _phoneError != null) return;
    final ctrl = ref.read(parcelFlowProvider.notifier);
    final d = ref.read(parcelFlowProvider).details;
    ctrl.updateDetails(d.copyWith(senderName: name, senderPhone: fullPhone(digits), pickupNote: _note.text.trim()));
    context.push(Routes.parcelDrop);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final pickup = ref.watch(parcelFlowProvider.select((s) => s.pickup));
    return Scaffold(
      backgroundColor: RidoColors.surface,
      appBar: const ParcelStepAppBar(title: 'Pickup details', step: 1),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ParcelLocationCard(place: pickup, isPickup: true, onChange: _changePlace),
                  const SizedBox(height: 20),
                  RidoTextField(
                    label: 'Sender name',
                    controller: _name,
                    errorText: _nameError,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                  ),
                  const SizedBox(height: 16),
                  ParcelPhoneField(
                    label: 'Sender phone',
                    controller: _phone,
                    errorText: _phoneError,
                    onChanged: (_) {
                      if (_phoneError != null) setState(() => _phoneError = null);
                    },
                  ),
                  const SizedBox(height: 16),
                  RidoTextField(
                    label: 'Building / floor / landmark',
                    hint: 'Flat, floor, building, nearby landmark',
                    controller: _note,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 6),
                  Text('Helps the driver find you faster', style: t.caption.copyWith(color: RidoColors.navy500)),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: RidoButton(label: 'Confirm pickup', onPressed: _confirm),
            ),
          ),
        ],
      ),
    );
  }
}
