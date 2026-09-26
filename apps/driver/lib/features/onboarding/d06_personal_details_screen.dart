import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../router/routes.dart';
import '../../state/driver_account.dart';
import '../../state/live_helpers.dart';
import 'widgets/signup_widgets.dart';

/// D-06 Personal details: photo, name, date of birth, gender, city (locked), the vehicle's model,
/// colour and number plate, emergency contact and the UPI ID that receives fares. "Save and continue"
/// → D-07. Live API: this is where the driver account (with its free trial) is created; the API's
/// validation messages (plate, UPI ID) show in a snack bar.
class D06PersonalDetailsScreen extends ConsumerStatefulWidget {
  const D06PersonalDetailsScreen({super.key, this.showcase = false});

  /// Opened on its own from the Design gallery: render seed state, start no timers.
  final bool showcase;

  @override
  ConsumerState<D06PersonalDetailsScreen> createState() => _D06PersonalDetailsScreenState();
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Parses "14 Mar 1994".
DateTime? _parseDob(String s) {
  final p = s.split(' ');
  if (p.length != 3) return null;
  final m = _months.indexOf(p[1]);
  final d = int.tryParse(p[0]);
  final y = int.tryParse(p[2]);
  if (m < 0 || d == null || y == null) return null;
  return DateTime(y, m + 1, d);
}

String _two(int n) => n.toString().padLeft(2, '0');

class _D06PersonalDetailsScreenState extends ConsumerState<D06PersonalDetailsScreen> {
  late final SignupDraft _draft = ref.read(signupProvider);
  late final TextEditingController _name = TextEditingController(text: _draft.name);
  late final TextEditingController _emergency =
      TextEditingController(text: _draft.emergencyContact.replaceFirst('+91', '').trim());
  late final TextEditingController _upi = TextEditingController(text: _draft.upiId);
  late final bool _live = ref.read(isLiveApiProvider);

  /// Mock: the seed driver's vehicle for the chosen type unless the driver typed one.
  late final DriverProfile _seedDriver = _draft.vehicle.isGoods ? Seed.selvam : Seed.karthik;
  late final TextEditingController _model =
      TextEditingController(text: _draft.vehicleModel.isNotEmpty || _live ? _draft.vehicleModel : _seedDriver.vehicleModel);
  late final TextEditingController _color =
      TextEditingController(text: _draft.vehicleColor.isNotEmpty || _live ? _draft.vehicleColor : _seedDriver.vehicleColor);
  late final TextEditingController _plate =
      TextEditingController(text: _draft.plate.isNotEmpty || _live ? _draft.plate : _seedDriver.plate);

  /// Live API: fields start empty, so errors show only after the first "Save and continue".
  bool _tried = false;
  late DateTime _dob = _parseDob(_draft.dob) ?? DateTime(1994, 6, 14);
  late Gender _gender = _draft.gender;
  late bool _hasPhoto = _draft.hasPhoto;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _emergency.dispose();
    _upi.dispose();
    _model.dispose();
    _color.dispose();
    _plate.dispose();
    super.dispose();
  }

  bool get _upiValid {
    final v = _upi.text.trim();
    if (_live) return kUpiPattern.hasMatch(v);
    final at = v.indexOf('@');
    return at > 0 && at < v.length - 1;
  }

  bool get _modelValid => _model.text.trim().length >= 2;
  bool get _plateValid => kPlatePattern.hasMatch(_plate.text.trim());
  bool get _showErrors => !_live || _tried;

  bool get _valid =>
      _name.text.trim().length >= 2 &&
      _upiValid &&
      PhoneInput.digitsOf(_emergency.text).length == 10 &&
      _modelValid &&
      _plateValid;

  String get _initials {
    final parts = _name.text.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'D';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob,
      firstDate: DateTime(1950),
      lastDate: DateTime(RidoClock.today.year - 18, RidoClock.today.month, RidoClock.today.day),
      helpText: 'Date of birth',
    );
    if (picked != null && mounted) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_valid) {
      setState(() => _tried = true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final digits = PhoneInput.digitsOf(_emergency.text);
    ref.read(signupProvider.notifier).update((d) => d.copyWith(
          name: _name.text.trim(),
          dob: formatDate(_dob),
          gender: _gender,
          emergencyContact: '+91 ${digits.substring(0, 5)} ${digits.substring(5)}',
          upiId: _upi.text.trim(),
          hasPhoto: _hasPhoto,
          vehicleModel: _model.text.trim(),
          vehicleColor: _color.text.trim(),
          plate: _plate.text.trim().toUpperCase(),
        ));
    try {
      await ref.read(signupProvider.notifier).commit();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showRidoSnack(context, userMessage(e));
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    context.push(Routes.documents);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Scaffold(
      backgroundColor: RidoColors.surface,
      appBar: SignupAppBar(title: 'Personal details', step: 3, onBack: backOr(context, Routes.chooseVehicle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(RidoSpacing.l, RidoSpacing.l, RidoSpacing.l, RidoSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _photoRow(t),
                  const SizedBox(height: RidoSpacing.l),
                  RidoTextField(
                    label: 'Full name (as on licence)',
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    errorText: _showErrors && _name.text.trim().length < 2 ? 'Enter your name as on your licence' : null,
                  ),
                  const SizedBox(height: RidoSpacing.l),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: RidoTextField(
                          key: ValueKey(_dob),
                          label: 'Date of birth',
                          initialValue: '${_two(_dob.day)}/${_two(_dob.month)}/${_dob.year}',
                          readOnly: true,
                          onTap: _pickDob,
                          suffix: IconButton(
                            tooltip: 'Pick date of birth',
                            icon: const Icon(Symbols.calendar_month_rounded, color: RidoColors.navy500),
                            onPressed: _pickDob,
                          ),
                        ),
                      ),
                      const SizedBox(width: RidoSpacing.m),
                      const Expanded(
                        child: RidoTextField(
                          label: 'City',
                          initialValue: 'Coimbatore',
                          enabled: false,
                          suffix: Icon(Symbols.lock_rounded, color: RidoColors.navy500, semanticLabel: 'Locked'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: RidoSpacing.l),
                  RidoTextField(
                    label: 'Vehicle model',
                    hint: _draft.vehicle.isGoods ? 'Bajaj Maxima Cargo' : 'Honda Activa',
                    controller: _model,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    errorText: _showErrors && !_modelValid ? 'Enter the vehicle model' : null,
                  ),
                  const SizedBox(height: RidoSpacing.l),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: RidoTextField(
                          label: 'Number plate',
                          hint: 'TN 37 AB 4521',
                          controller: _plate,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setState(() {}),
                          errorText: _showErrors && !_plateValid ? 'Like TN 37 AB 4521' : null,
                        ),
                      ),
                      const SizedBox(width: RidoSpacing.m),
                      Expanded(
                        child: RidoTextField(
                          label: 'Colour',
                          controller: _color,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: RidoSpacing.l),
                  Text('Gender', style: t.bodySmallMedium.copyWith(color: RidoColors.navy700)),
                  const SizedBox(height: 6),
                  ChoiceChips<Gender>(
                    options: const [Gender.male, Gender.female, Gender.preferNotToSay],
                    labelOf: (g) => switch (g) {
                      Gender.male => 'Male',
                      Gender.female => 'Female',
                      Gender.preferNotToSay => 'Other',
                    },
                    selected: {_gender},
                    onChanged: (g) => setState(() => _gender = g),
                  ),
                  const SizedBox(height: RidoSpacing.l),
                  PhoneInput(
                    label: 'Emergency contact',
                    controller: _emergency,
                    onChanged: (_) => setState(() {}),
                    errorText: !_showErrors || PhoneInput.digitsOf(_emergency.text).length == 10 ? null : 'Enter a 10-digit number',
                  ),
                  const SizedBox(height: RidoSpacing.l),
                  RidoTextField(
                    label: 'UPI ID for receiving fares',
                    controller: _upi,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    errorText: !_showErrors || _upiValid ? null : 'Enter a valid UPI ID, like name@bank',
                    suffix: _upiValid
                        ? const Icon(Symbols.check_circle_rounded,
                            color: RidoColors.success, fill: 1, semanticLabel: 'Valid UPI ID')
                        : null,
                  ),
                  if (_upiValid && !_live) ...[
                    const SizedBox(height: 6),
                    Text('Verified · ${_name.text.trim().toUpperCase()}',
                        style: t.caption.copyWith(color: RidoColors.successText, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
          ),
          BottomActions(
            children: [
              RidoButton(label: 'Save and continue', loading: _saving, onPressed: _valid || _live ? _save : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photoRow(RidoTextStyles t) {
    return Semantics(
      button: true,
      label: _hasPhoto ? 'Remove profile photo' : 'Add profile photo',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: RidoRadii.cardRadius,
        onTap: () => setState(() => _hasPhoto = !_hasPhoto),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: RidoSpacing.xs),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  children: [
                    if (_hasPhoto)
                      RidoAvatar(initials: _initials, size: 84, tone: AvatarTone.dark)
                    else
                      Container(
                        width: 84,
                        height: 84,
                        decoration: const BoxDecoration(color: RidoColors.coral50, shape: BoxShape.circle),
                        child: const DashedRing(
                          size: 84,
                          color: RidoColors.coral100,
                          strokeWidth: 2,
                          dash: 6,
                          gap: 5,
                          child: Icon(Symbols.person_rounded, color: RidoColors.coral600, size: 36),
                        ),
                      ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: RidoColors.coral600,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(_hasPhoto ? Symbols.edit_rounded : Symbols.photo_camera_rounded,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: RidoSpacing.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_hasPhoto ? 'Profile photo added' : 'Add profile photo', style: t.bodySemibold),
                    Text(_hasPhoto ? 'Tap to remove or retake.' : 'Riders see this. Clear face, no sunglasses.',
                        style: t.bodySmall.copyWith(color: RidoColors.navy500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
