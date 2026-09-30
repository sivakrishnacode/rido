import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_driver/features/jobs/widgets/request_layout.dart';
import 'package:tamiltaxi_driver/state/request_voice.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSpeaker implements RequestSpeaker {
  final said = <(String, VoiceLanguage)>[];
  int stops = 0;

  @override
  Future<void> speak(String text, VoiceLanguage language) async => said.add((text, language));

  @override
  Future<void> stop() async => stops++;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the request is read with fare, pickup distance and area, and trip length', () {
    final r = Seed.rideRequest;
    final en = RequestSpeech.of(r, VoiceLanguage.english);
    expect(en, startsWith('New ride. ${r.fare} rupees.'));
    expect(en, contains('Pickup ${r.pickupDistanceKm.toStringAsFixed(1)} kilometres, ${r.pickup.name}.'));
    expect(en, endsWith('Trip ${r.tripKm.toStringAsFixed(1)} kilometres.'));
    expect(RequestSpeech.of(Seed.deliveryRequest, VoiceLanguage.english), startsWith('New delivery.'));
    expect(RequestSpeech.of(r, VoiceLanguage.tamil), startsWith('புதிய சவாரி. ${r.fare} ரூபாய்.'));
  });

  test("the rider's extra is read after the fare", () {
    final r = Seed.rideRequest.copyWith(fare: 70, extra: 20);
    expect(RequestSpeech.of(r, VoiceLanguage.english), startsWith('New ride. 50 rupees plus 20 extra.'));
    expect(RequestSpeech.of(r, VoiceLanguage.tamil), startsWith('புதிய சவாரி. 50 ரூபாய், கூடுதல் 20 ரூபாய்.'));
  });

  test('announces only while voice is on, in the chosen language, and remembers the choice', () async {
    final speaker = _FakeSpeaker();
    final container = ProviderContainer(overrides: [requestSpeakerProvider.overrideWithValue(speaker)]);
    addTearDown(container.dispose);
    final voice = container.read(requestVoiceProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    await voice.setLanguage(VoiceLanguage.tamil);
    final s = container.read(requestVoiceProvider);
    expect(s.enabled, isTrue, reason: 'on by default');
    expect(s.language, VoiceLanguage.tamil);

    await voice.setEnabled(false);
    expect(speaker.stops, 1, reason: 'muting stops a sentence in progress');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('request_voice_enabled'), isFalse);
    expect(prefs.getString('request_voice_language'), 'tamil');
  });

  testWidgets('the speaker button on the request mutes and unmutes', (tester) async {
    final speaker = _FakeSpeaker();
    await tester.pumpWidget(ProviderScope(
      overrides: [requestSpeakerProvider.overrideWithValue(speaker)],
      child: MaterialApp(theme: TtTheme.light(), home: const Scaffold(body: Center(child: RequestVoiceToggle()))),
    ));
    await tester.pump();
    expect(find.byIcon(Symbols.volume_up_rounded), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(find.byIcon(Symbols.volume_off_rounded), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(find.byIcon(Symbols.volume_up_rounded), findsOneWidget);
  });
}
