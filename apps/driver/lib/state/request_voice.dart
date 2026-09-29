import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Language the request is read out in. The phone's own text-to-speech voice is used (Google TTS ships Tamil).
enum VoiceLanguage {
  english('en-IN', 'English'),
  tamil('ta-IN', 'தமிழ்');

  const VoiceLanguage(this.locale, this.label);
  final String locale;
  final String label;
}

/// Read-aloud settings for new requests: on by default, English by default. Saved on the phone.
@immutable
class RequestVoiceSettings {
  const RequestVoiceSettings({this.enabled = true, this.language = VoiceLanguage.english});
  final bool enabled;
  final VoiceLanguage language;

  RequestVoiceSettings copyWith({bool? enabled, VoiceLanguage? language}) =>
      RequestVoiceSettings(enabled: enabled ?? this.enabled, language: language ?? this.language);
}

class RequestVoiceController extends Notifier<RequestVoiceSettings> {
  static const _enabledKey = 'request_voice_enabled';
  static const _languageKey = 'request_voice_language';

  @override
  RequestVoiceSettings build() {
    unawaited(_load());
    return const RequestVoiceSettings();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = VoiceLanguage.values.where((l) => l.name == prefs.getString(_languageKey)).firstOrNull;
      if (!ref.mounted) return;
      state = RequestVoiceSettings(enabled: prefs.getBool(_enabledKey) ?? true, language: lang ?? VoiceLanguage.english);
    } catch (e) {
      debugPrint('Voice settings unavailable: $e');
    }
  }

  Future<void> setEnabled(bool on) async {
    state = state.copyWith(enabled: on);
    if (!on) unawaited(ref.read(requestSpeakerProvider).stop());
    try {
      await (await SharedPreferences.getInstance()).setBool(_enabledKey, on);
    } catch (_) {}
  }

  Future<void> setLanguage(VoiceLanguage language) async {
    state = state.copyWith(language: language);
    try {
      await (await SharedPreferences.getInstance()).setString(_languageKey, language.name);
    } catch (_) {}
  }
}

final requestVoiceProvider = NotifierProvider<RequestVoiceController, RequestVoiceSettings>(RequestVoiceController.new);

/// Speaks a line; replaced in tests.
abstract class RequestSpeaker {
  Future<void> speak(String text, VoiceLanguage language);
  Future<void> stop();
}

class TtsRequestSpeaker implements RequestSpeaker {
  FlutterTts? _tts;

  @override
  Future<void> speak(String text, VoiceLanguage language) async {
    try {
      final tts = _tts ??= FlutterTts();
      // No Tamil voice installed: English rather than silence.
      final hasLanguage = await tts.isLanguageAvailable(language.locale) == true;
      final spoken = hasLanguage ? language : VoiceLanguage.english;
      await tts.setLanguage(spoken.locale);
      await tts.setSpeechRate(0.5);
      await tts.stop();
      await tts.speak(spoken == language ? text : RequestSpeech.fallback);
    } catch (e) {
      debugPrint('Text-to-speech unavailable: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}

final requestSpeakerProvider = Provider<RequestSpeaker>((ref) => TtsRequestSpeaker());

/// What is said for a request: kind, fare, pickup distance and area, trip length. Numbers as digits so the TTS
/// engine reads them in the chosen language.
abstract final class RequestSpeech {
  /// Said when the chosen language has no voice on the phone.
  static const fallback = 'New request';

  static String of(RideRequest r, VoiceLanguage language) {
    final pickupKm = r.pickupDistanceKm.toStringAsFixed(1);
    final tripKm = r.tripKm.toStringAsFixed(1);
    return switch (language) {
      VoiceLanguage.english => '${r.isDelivery ? 'New delivery' : 'New ride'}. ${r.fare} rupees. '
          'Pickup $pickupKm kilometres, ${r.pickup.name}. Trip $tripKm kilometres.',
      VoiceLanguage.tamil => '${r.isDelivery ? 'புதிய டெலிவரி' : 'புதிய சவாரி'}. ${r.fare} ரூபாய். '
          'பிக்கப் $pickupKm கிலோமீட்டர், ${r.pickup.name}. பயணம் $tripKm கிலோமீட்டர்.',
    };
  }
}

/// Reads [request] aloud when the driver has voice on.
void announceRequest(WidgetRef ref, RideRequest request) {
  final settings = ref.read(requestVoiceProvider);
  if (!settings.enabled) return;
  unawaited(ref.read(requestSpeakerProvider).speak(RequestSpeech.of(request, settings.language), settings.language));
}
