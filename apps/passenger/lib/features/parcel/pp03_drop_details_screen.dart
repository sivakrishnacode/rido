import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../router/routes.dart';
import '../../state/parcel_flow.dart';
import '../../state/passenger_session.dart';
import 'widgets/parcel_widgets.dart';

/// Sample landmark shown on PP-03.
const _sampleDropNote = 'House 14, near Race Course walking track';

/// Seeded phone contacts for "Choose from contacts".
const _contacts = [
  (name: Seed.receiverName, phone: Seed.receiverPhone),
  (name: 'Karthika Sundar', phone: '+91 98430 56712'),
  (name: 'Suresh Kumar', phone: '+91 99440 23581'),
];

/// What a drop can be saved as from PP-03 (a Shop is saved as an "other" place with that label).
enum _SaveAs {
  home('Home', Symbols.home_rounded, SavedPlaceKind.home),
  work('Work', Symbols.work_rounded, SavedPlaceKind.work),
  shop('Shop', Symbols.storefront_rounded, SavedPlaceKind.other);

  const _SaveAs(this.label, this.icon, this.kind);
  final String label;
  final IconData icon;
  final SavedPlaceKind kind;
}

/// PP-03 Drop / receiver details: the drop (any town when sending to another town), the receiver (or "I'm receiving
/// it myself"), a landmark, and optionally save the drop as Home / Work / Shop.
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

  /// "I'm receiving it myself": the receiver is the sender (fields filled and locked).
  bool _self = false;
  _SaveAs? _saveAs;

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
    final outstation = ref.read(parcelFlowProvider).outstation;
    final p = await showParcelPlacePicker(context, title: outstation ? 'Deliver to (any town)' : 'Deliver to', current: _drop, anywhere: outstation);
    if (p == null || !mounted) return;
    setState(() => _drop = p);
    ref.read(parcelFlowProvider.notifier).setDrop(p);
  }

  Future<void> _pickContact() async {
    final picked = await showTtSheet<({String name, String phone})>(
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
                    TtAvatar(initials: _initials(c.name), size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, style: ctx.type.bodyMedium),
                          Text(c.phone, style: TtTextStyles.tabular(ctx.type.bodySmall.copyWith(color: TtColors.navy500))),
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

  void _setSelf(bool v) {
    final d = ref.read(parcelFlowProvider).details;
    final me = ref.read(passengerProfileProvider).value;
    final name = d.senderName.trim().isNotEmpty ? d.senderName : (me?.name ?? '');
    final phone = d.senderPhone.trim().isNotEmpty ? d.senderPhone : (me?.phone ?? '');
    setState(() {
      _self = v;
      _nameError = null;
      _phoneError = null;
      if (v) {
        _name.text = name;
        _phone.text = localPhone(phone);
      } else {
        _name.clear();
        _phone.clear();
      }
    });
  }

  /// Saves the drop as [_saveAs] (one Home and one Work: a new one replaces the old). Fire and forget.
  void _saveDrop() {
    final as = _saveAs;
    if (as == null) return;
    final saved = ref.read(passengerProfileProvider).value?.savedPlaces ?? const <SavedPlace>[];
    final same = as.kind == SavedPlaceKind.other ? null : saved.where((s) => s.kind == as.kind).firstOrNull;
    final place = SavedPlace(
      id: same?.id ?? 'sp-${DateTime.now().microsecondsSinceEpoch}',
      label: as.label,
      kind: as.kind,
      place: _drop,
    );
    ref.read(passengerProfileProvider.notifier).saveSavedPlace(place).then((ok) {
      if (ok && mounted) showTtSnack(context, '${_drop.name} saved as ${as.label}', success: true);
    });
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
    _saveDrop();
    context.push(Routes.parcelDetails);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final firstName = _name.text.trim().isEmpty ? 'The receiver' : _name.text.trim().split(' ').first;
    return Scaffold(
      backgroundColor: TtColors.surface,
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
                  const SizedBox(height: 16),
                  _SelfToggle(value: _self, onChanged: _setSelf),
                  const SizedBox(height: 12),
                  TtTextField(
                    label: 'Receiver name',
                    controller: _name,
                    enabled: !_self,
                    errorText: _nameError,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() => _nameError = null),
                  ),
                  const SizedBox(height: 16),
                  ParcelPhoneField(
                    label: 'Receiver phone',
                    controller: _phone,
                    enabled: !_self,
                    errorText: _phoneError,
                    onChanged: (_) {
                      if (_phoneError != null) setState(() => _phoneError = null);
                    },
                    // The contact list is seeded demo data; the live app has no contacts permission.
                    suffix: ref.watch(isLiveApiProvider) || _self
                        ? null
                        : IconButton(
                            tooltip: 'Choose from contacts',
                            onPressed: _pickContact,
                            icon: const Icon(Symbols.contact_page_rounded, color: TtColors.coral600),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(_self ? 'You get the delivery OTP in the app' : '$firstName gets the delivery OTP and a tracking link by SMS',
                      style: t.caption.copyWith(color: TtColors.navy500)),
                  const SizedBox(height: 16),
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Landmark '),
                      TextSpan(text: '(optional)', style: t.bodySmall.copyWith(color: TtColors.navy500)),
                    ]),
                    style: t.bodySmallMedium.copyWith(color: TtColors.navy700),
                  ),
                  const SizedBox(height: 6),
                  TtTextField(
                    hint: 'House number, nearby landmark',
                    controller: _note,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 20),
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Save this address '),
                      TextSpan(text: '(optional)', style: t.bodySmall.copyWith(color: TtColors.navy500)),
                    ]),
                    style: t.bodySmallMedium.copyWith(color: TtColors.navy700),
                  ),
                  const SizedBox(height: 8),
                  ChoiceChips<_SaveAs>(
                    options: _SaveAs.values,
                    labelOf: (a) => a.label,
                    iconOf: (a) => a.icon,
                    selected: {?_saveAs},
                    onChanged: (a) => setState(() => _saveAs = _saveAs == a ? null : a),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TtButton(label: 'Confirm drop', onPressed: _confirm),
            ),
          ),
        ],
      ),
    );
  }
}

/// "I'm receiving it myself".
class _SelfToggle extends StatelessWidget {
  const _SelfToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Material(
      color: value ? TtColors.coral50 : TtColors.inputBg,
      borderRadius: TtRadii.cardRadius,
      child: InkWell(
        borderRadius: TtRadii.cardRadius,
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(
            children: [
              Icon(Symbols.person_pin_circle_rounded, color: value ? TtColors.coral600 : TtColors.navy700),
              const SizedBox(width: 10),
              Expanded(child: Text("I'm receiving it myself", style: t.bodyMedium)),
              Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
            ],
          ),
        ),
      ),
    );
  }
}
