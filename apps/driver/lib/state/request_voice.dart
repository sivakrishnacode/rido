import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
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
    final base = r.fare - r.extra;
    final terms = r.modeTerms;
    final roundTrip = terms is OutstationTerms && terms.roundTrip;
    final at = r.scheduledAt;
    final shift = r.shifting;
    final helpers = shift?.lines?.helperCount;
    return switch (language) {
      VoiceLanguage.english => '${switch (terms) {
            _ when shift != null => 'New packers and movers job, ${shift.homeSize.label}${helpers == null ? '' : ', bring $helpers helpers'}',
            RentalTerms t => 'New rental, ${t.hours} ${t.hours == 1 ? 'hour' : 'hours'}',
            OutstationTerms() => 'New outstation trip to ${r.drop.name}${roundTrip ? ', round trip' : ''}',
            null => r.isDelivery ? 'New delivery' : 'New ride',
          }}. '
          '${at == null ? '' : 'Pickup ${_whenEnglish(at)}. '}'
          '${r.extra > 0 ? '$base rupees plus ${r.extra} extra' : '${r.fare} rupees'}. '
          'Pickup $pickupKm kilometres, ${r.pickup.name}.${r.isRental ? '' : ' Trip $tripKm kilometres.'}',
      VoiceLanguage.tamil => '${switch (terms) {
            _ when shift != null => 'புதிய வீடு மாற்றம், ${shift.homeSize.label}${helpers == null ? '' : ', $helpers உதவியாளர்கள்'}',
            RentalTerms t => 'புதிய வாடகை சவாரி, ${t.hours} மணி நேரம்',
            OutstationTerms() => 'புதிய வெளியூர் சவாரி, ${r.drop.name}${roundTrip ? ', போய் வர' : ''}',
            null => r.isDelivery ? 'புதிய டெலிவரி' : 'புதிய சவாரி',
          }}. '
          '${at == null ? '' : 'பிக்கப் ${_whenTamil(at)}. '}'
          '${r.extra > 0 ? '$base ரூபாய், கூடுதல் ${r.extra} ரூபாய்' : '${r.fare} ரூபாய்'}. '
          'பிக்கப் $pickupKm கிலோமீட்டர், ${r.pickup.name}.${r.isRental ? '' : ' பயணம் $tripKm கிலோமீட்டர்.'}',
    };
  }

  /// "today at 6:30 PM", "tomorrow at 6:00 AM", "on 9 October at 9:15 AM".
  static String _whenEnglish(DateTime at) {
    final day = _dayOffset(at);
    final time = DateFormat('h:mm a').format(at);
    return switch (day) {
      0 => 'today at $time',
      1 => 'tomorrow at $time',
      _ => 'on ${DateFormat('d MMMM').format(at)} at $time',
    };
  }

  /// "இன்று 6:30 PM", "நாளை 6:00 AM", "9/10 9:15 AM" (the TTS reads the digits in Tamil).
  static String _whenTamil(DateTime at) {
    final time = DateFormat('h:mm a').format(at);
    return switch (_dayOffset(at)) {
      0 => 'இன்று $time',
      1 => 'நாளை $time',
      _ => '${at.day}/${at.month} $time',
    };
  }

  static int _dayOffset(DateTime at) {
    final now = DateTime.now();
    return DateTime(at.year, at.month, at.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  }
}

/// Reads [request] aloud when the driver has voice on.
void announceRequest(WidgetRef ref, RideRequest request) {
  final settings = ref.read(requestVoiceProvider);
  if (!settings.enabled) return;
  unawaited(ref.read(requestSpeakerProvider).speak(RequestSpeech.of(request, settings.language), settings.language));
}
