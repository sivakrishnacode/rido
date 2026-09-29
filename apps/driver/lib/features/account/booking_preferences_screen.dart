import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../state/booking_prefs.dart';
import '../../state/driver_session.dart';
import '../../state/live_helpers.dart';
import '../../state/request_voice.dart';
import 'widgets/edit_form_scaffold.dart';

/// Account › Booking preferences (like Namma Yatri's): read requests aloud (and in which language), go home (only
/// trips towards the saved Home spot, for two hours), the farthest pickup, and trip length limits. Saved to the
/// API; dispatch only offers trips that fit. Voice is saved on the phone at once.
class BookingPreferencesScreen extends ConsumerStatefulWidget {
  const BookingPreferencesScreen({super.key});

  @override
  ConsumerState<BookingPreferencesScreen> createState() => _BookingPreferencesScreenState();
}

/// Pickup limits offered (km).
const kPickupSteps = [1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 7.0, 10.0];

/// Trip length limits offered (km).
const kTripSteps = [2.0, 3.0, 5.0, 8.0, 10.0, 15.0, 20.0, 30.0, 50.0];

class _BookingPreferencesScreenState extends ConsumerState<BookingPreferencesScreen> {
  BookingPrefs? _draft;
  bool _saving = false;

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    if (draft.minTripKm != null && draft.maxTripKm != null && draft.minTripKm! >= draft.maxTripKm!) {
      showTtSnack(context, 'The shortest trip must be less than the longest trip');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(bookingPrefsProvider.notifier).save(draft);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showTtSnack(context, userMessage(e));
      return;
    }
    if (!mounted) return;
    showTtSnack(context, draft.hasFilters ? 'Saved. You only get requests that fit' : 'Saved. You get every request',
        success: true);
    context.pop();
  }

  /// "Save my location as Home" from the latest GPS fix.
  Future<void> _saveHereAsHome() async {
    final here = ref.read(driverSessionProvider.notifier).position ?? ref.read(driverSessionProvider.notifier).vehicle.value?.position;
    if (here == null) {
      showTtSnack(context, 'Waiting for your location. Try again in a moment');
      return;
    }
    await ref.read(savedHomeProvider.notifier).set(here);
    if (mounted) showTtSnack(context, 'Home saved', success: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final loaded = ref.watch(bookingPrefsProvider);
    final draft = _draft ?? loaded.value;
    if (_draft == null && loaded.hasValue) _draft = loaded.value;
    final voice = ref.watch(requestVoiceProvider);
    final home = ref.watch(savedHomeProvider);

    void update(BookingPrefs next) => setState(() => _draft = next);

    return EditFormScaffold(
      title: 'Booking preferences',
      saving: _saving,
      loading: draft == null && !loaded.hasError,
      onSave: draft == null ? null : _save,
      children: draft == null
          ? [Text("Couldn't load your preferences. Check your internet and try again.", style: t.body)]
          : [
              Text('Choose which requests reach you. Fewer filters means more requests.',
                  style: t.body.copyWith(color: TtColors.navy700)),
              const SizedBox(height: TtSpacing.l),
              _Card(children: [
                _SwitchRow(
                  icon: Symbols.record_voice_over_rounded,
                  title: 'Read requests aloud',
                  subtitle: 'Fare, pickup and trip distance',
                  value: voice.enabled,
                  onChanged: (v) => ref.read(requestVoiceProvider.notifier).setEnabled(v),
                ),
                if (voice.enabled) ...[
                  const SizedBox(height: TtSpacing.m),
                  TtSegmented<VoiceLanguage>(
                    options: VoiceLanguage.values,
                    labelOf: (l) => l.label,
                    selected: voice.language,
                    onChanged: (l) => ref.read(requestVoiceProvider.notifier).setLanguage(l),
                  ),
                ],
              ]),
              const SizedBox(height: TtSpacing.m),
              _Card(children: [
                _SwitchRow(
                  icon: Symbols.home_pin_rounded,
                  title: 'Go home',
                  subtitle: draft.goTo?.until != null
                      ? 'Only trips towards Home · on till ${formatTime(draft.goTo!.until!)}'
                      : home == null
                          ? 'Save your Home first'
                          : 'Only trips towards Home, for 2 hours',
                  value: draft.goTo != null,
                  onChanged: home == null
                      ? null
                      : (v) => update(draft.copyWith(goTo: () => v ? GoToDestination(location: home, name: 'Home') : null)),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TtButton.text(
                    label: home == null ? 'Save my location as Home' : 'Update Home to my location',
                    onPressed: _saveHereAsHome,
                  ),
                ),
              ]),
              const SizedBox(height: TtSpacing.m),
              _Card(children: [
                _RowTitle(icon: Symbols.near_me_rounded, title: 'Farthest pickup'),
                const SizedBox(height: TtSpacing.s),
                _Stepper(
                  label: draft.maxPickupKm == null ? 'Any distance' : '${formatKm(draft.maxPickupKm!)} max',
                  steps: kPickupSteps,
                  value: draft.maxPickupKm,
                  onChanged: (v) => update(draft.copyWith(maxPickupKm: () => v)),
                ),
              ]),
              const SizedBox(height: TtSpacing.m),
              _Card(children: [
                _RowTitle(icon: Symbols.route_rounded, title: 'Trip length'),
                const SizedBox(height: TtSpacing.s),
                _LimitRow(
                  label: 'Longer than',
                  value: draft.minTripKm,
                  onChanged: (v) => update(draft.copyWith(minTripKm: () => v)),
                  fallback: 5,
                ),
                const Divider(height: TtSpacing.xl),
                _LimitRow(
                  label: 'Shorter than',
                  value: draft.maxTripKm,
                  onChanged: (v) => update(draft.copyWith(maxTripKm: () => v)),
                  fallback: 15,
                ),
              ]),
              const SizedBox(height: TtSpacing.l),
              Text('Pickup distance is a straight line from you. Filters never change the fare.',
                  style: t.bodySmall.copyWith(color: TtColors.navy500)),
            ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(TtSpacing.l),
        decoration: BoxDecoration(
          color: TtColors.surface,
          borderRadius: TtRadii.cardRadius,
          border: Border.all(color: TtColors.divider),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class _RowTitle extends StatelessWidget {
  const _RowTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: TtColors.coral600, size: 24),
        const SizedBox(width: TtSpacing.m),
        Expanded(child: Text(title, style: context.type.bodySemibold)),
      ]);
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: Row(children: [
          Icon(icon, color: TtColors.coral600, size: 24),
          const SizedBox(width: TtSpacing.m),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: context.type.bodySemibold),
              Text(subtitle, style: context.type.bodySmall.copyWith(color: TtColors.navy500)),
            ]),
          ),
          Switch(value: value, onChanged: onChanged),
        ]),
      );
}

/// − "2 km max" +, stepping through [steps]; below the first step is "Any" (null).
class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.steps, required this.value, required this.onChanged});
  final String label;
  final List<double> steps;
  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final i = value == null ? -1 : steps.indexWhere((s) => s >= value!);
    final at = value != null && i == -1 ? steps.length - 1 : i;
    return Row(children: [
      IconButton.filledTonal(
        tooltip: 'Less',
        onPressed: at < 0 ? null : () => onChanged(at == 0 ? null : steps[at - 1]),
        icon: const Icon(Symbols.remove_rounded),
      ),
      Expanded(child: Text(label, textAlign: TextAlign.center, style: context.type.bodySemibold)),
      IconButton.filledTonal(
        tooltip: 'More',
        onPressed: at >= steps.length - 1 ? null : () => onChanged(steps[at + 1]),
        icon: const Icon(Symbols.add_rounded),
      ),
    ]);
  }
}

/// [x] Longer than − 5 km +: the checkbox turns the limit on (at [fallback]) or off.
class _LimitRow extends StatelessWidget {
  const _LimitRow({required this.label, required this.value, required this.onChanged, required this.fallback});
  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;
  final double fallback;

  @override
  Widget build(BuildContext context) {
    final on = value != null;
    return Row(children: [
      Checkbox(value: on, onChanged: (v) => onChanged(v == true ? fallback : null)),
      Expanded(child: Text(label, style: context.type.body)),
      if (on)
        SizedBox(
          width: 190,
          child: _Stepper(
            label: formatKm(value!),
            steps: kTripSteps,
            value: value,
            // The stepper's "below the first step" means off; keep the smallest step instead.
            onChanged: (v) => onChanged(v ?? kTripSteps.first),
          ),
        ),
    ]);
  }
}
