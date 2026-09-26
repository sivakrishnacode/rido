import 'package:flutter/material.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Phone calls, SMS, WhatsApp and the system share sheet (url_launcher / share_plus). Each shows a snack
/// instead of failing when the phone has no app for it.

/// Dials [phone] in the phone app (the passenger presses call; no CALL_PHONE permission needed).
Future<void> callNumber(BuildContext context, String phone, {String? name}) async {
  final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.isEmpty) {
    showRidoSnack(context, name == null ? 'No phone number available' : "$name's number isn't available");
    return;
  }
  await _open(context, Uri(scheme: 'tel', path: digits), 'Could not open the phone app');
}

/// Opens the SMS app with [body], addressed to [to] when given.
Future<void> openSms(BuildContext context, String body, {String? to}) async {
  final number = (to ?? '').replaceAll(RegExp(r'[^\d+]'), '');
  // Encoded by hand: Uri(queryParameters:) writes spaces as "+", which some SMS apps show literally.
  final uri = Uri.parse('sms:$number?body=${Uri.encodeComponent(body)}');
  await _open(context, uri, 'Could not open messages');
}

/// Opens WhatsApp's "send to…" picker with [text] (falls back to the browser's wa.me page).
Future<void> openWhatsApp(BuildContext context, String text) async {
  final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
  await _open(context, uri, 'WhatsApp is not installed');
}

/// The system share sheet ("More").
Future<void> shareText(BuildContext context, String text, {String? subject}) async {
  try {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  } catch (_) {
    if (context.mounted) showRidoSnack(context, 'Could not open share options');
  }
}

/// Opens a `upi://pay` link in the phone's UPI app (GPay, PhonePe, Paytm, BHIM…).
Future<void> openUpi(BuildContext context, Uri uri) =>
    _open(context, uri, 'No UPI app found. Scan the QR code from another phone');

Future<void> _open(BuildContext context, Uri uri, String failure) async {
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) showRidoSnack(context, failure);
}

/// Text for "Share trip": who is driving (name, plate, vehicle), where to, and where the vehicle is now.
String tripShareText({
  required String riderName,
  required DriverProfile driver,
  required String vehicleLabel,
  required Place drop,
  LatLng? vehicleAt,
  String? status,
  bool parcel = false,
}) {
  final vehicle = [driver.vehicleColor, driver.vehicleModel].where((s) => s.trim().isNotEmpty).join(' ');
  final lines = [
    parcel ? "$riderName's Rido parcel to ${drop.name}" : "$riderName's Rido ride to ${drop.name}",
    'Driver: ${driver.name}',
    'Vehicle: ${vehicle.isEmpty ? vehicleLabel : '$vehicle ($vehicleLabel)'} · ${driver.plate}',
    if (drop.address.isNotEmpty) 'Drop: ${drop.address}',
    ?status,
    if (vehicleAt != null)
      'Now at: https://maps.google.com/?q=${vehicleAt.latitude.toStringAsFixed(5)},${vehicleAt.longitude.toStringAsFixed(5)}',
  ];
  return lines.join('\n');
}
