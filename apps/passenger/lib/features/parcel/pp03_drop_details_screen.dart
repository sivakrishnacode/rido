import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/parcel_flow.dart';
import 'widgets/parcel_widgets.dart';

/// Sample landmark shown on PP-03.
const _sampleDropNote = 'House 14, near Race Course walking track';

/// Seeded phone contacts for "Choose from contacts".
const _contacts = [
  (name: Seed.receiverName, phone: Seed.receiverPhone),
  (name: 'Karthika Sundar', phone: '+91 98430 56712'),
  (name: 'Suresh Kumar', phone: '+91 99440 23581'),
];

/// PP-03 Drop / receiver details.
class PP03DropDetailsScreen extends ConsumerStatefulWidget {
  const PP03DropDetailsScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<PP03DropDetailsScreen> createState() => _PP03DropDetailsScreenState();
}

class _PP03DropDetailsScreenState extends ConsumerState<PP03DropDetailsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _note;
  late Place _drop;
  String? _nameError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    final s = ref.read(parcelFlowProvider);
    _drop = s.drop;
    _name = TextEditingController(text: s.details.receiverName);
    _phone = TextEditingController(text: localPhone(s.details.receiverPhone));
    final live = ref.read(isLiveApiProvider);
    _note = TextEditingController(text: s.details.dropNote.isEmpty && !live ? _sampleDropNote : s.details.dropNote);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _changePlace() async {
    final p = await showParcelPlacePicker(context, title: 'Deliver to', current: _drop);
    if (p == null || !mounted) return;
    setState(() => _drop = p);
    ref.read(parcelFlowProvider.notifier).setDrop(p);
  }

  Future<void> _pickContact() async {
    final picked = await showRidoSheet<({String name, String phone})>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Choose a contact', style: ctx.type.h2),
          const SizedBox(height: 8),
          for (final c in _contacts)
            InkWell(
              onTap: () => Navigator.of(ctx).pop(c),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    RidoAvatar(initials: _initials(c.name), size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, style: ctx.type.bodyMedium),
                          Text(c.phone, style: RidoTextStyles.tabular(ctx.type.bodySmall.copyWith(color: RidoColors.navy500))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _name.text = picked.name;
      _phone.text = localPhone(picked.phone);
      _nameError = null;
      _phoneError = null;
    });
  }

  static String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+'));
    return (p.first.substring(0, 1) + (p.length > 1 ? p[1].substring(0, 1) : '')).toUpperCase();
  }

  void _confirm() {
    final name = _name.text.trim();
    final digits = phoneDigits(_phone.text);
    setState(() {
      _nameError = name.isEmpty ? 'Enter the receiver’s name' : null;
      _phoneError = digits.length != 10 ? 'Enter a 10-digit mobile number' : null;
    });
    if (_nameError != null || _phoneError != null) return;
    final ctrl = ref.read(parcelFlowProvider.notifier);
    ctrl.setDrop(_drop);
    final d = ref.read(parcelFlowProvider).details;
    ctrl.updateDetails(d.copyWith(receiverName: name, receiverPhone: fullPhone(digits), dropNote: _note.text.trim()));
    context.push(Routes.parcelDetails);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final firstName = _name.text.trim().isEmpty ? 'The receiver' : _name.text.trim().split(' ').first;
    return Scaffold(
      backgroundColor: RidoColors.surface,
      appBar: const ParcelStepAppBar(title: 'Drop details', step: 2),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ParcelLocationCard(place: _drop, isPickup: false, onChange: _changePlace),
                  const SizedBox(height: 20),
                  RidoTextField(
                    label: 'Receiver name',
                    controller: _name,
                    errorText: _nameError,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() => _nameError = null),
                  ),
                  const SizedBox(height: 16),
                  ParcelPhoneField(
                    label: 'Receiver phone',
                    controller: _phone,
                    errorText: _phoneError,
                    onChanged: (_) {
                      if (_phoneError != null) setState(() => _phoneError = null);
                    },
                    // The contact list is seeded demo data; the live app has no contacts permission.
                    suffix: ref.watch(isLiveApiProvider)
                        ? null
                        : IconButton(
                            tooltip: 'Choose from contacts',
                            onPressed: _pickContact,
                            icon: const Icon(Symbols.contact_page_rounded, color: RidoColors.coral600),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text('$firstName gets the delivery OTP and a tracking link by SMS',
                      style: t.caption.copyWith(color: RidoColors.navy500)),
                  const SizedBox(height: 16),
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Landmark '),
                      TextSpan(text: '(optional)', style: t.bodySmall.copyWith(color: RidoColors.navy500)),
                    ]),
                    style: t.bodySmallMedium.copyWith(color: RidoColors.navy700),
                  ),
                  const SizedBox(height: 6),
                  RidoTextField(
                    hint: 'House number, nearby landmark',
                    controller: _note,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: RidoButton(label: 'Confirm drop', onPressed: _confirm),
            ),
          ),
        ],
      ),
    );
  }
}
