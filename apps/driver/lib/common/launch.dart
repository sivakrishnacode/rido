import 'package:flutter/widgets.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the phone dialer with [phone] (a customer, the emergency contact or 112).
/// Shows a snack when there is no number or no dialer.
Future<void> dialNumber(BuildContext context, String phone, {String? name}) async {
  final number = phone.replaceAll(RegExp(r'[^\d+]'), '');
  if (number.isEmpty) {
    showRidoSnack(context, name == null ? 'No phone number' : 'No phone number for $name');
    return;
  }
  var opened = false;
  try {
    opened = await launchUrl(Uri(scheme: 'tel', path: number));
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) showRidoSnack(context, 'Could not open the dialer. Call $number');
}

/// Turn-by-turn navigation to [to] in Google Maps (or the browser). The app itself never calls a
/// routing API on a timer.
Future<void> openNavigation(BuildContext context, LatLng to) async {
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '${to.latitude},${to.longitude}',
    'travelmode': 'driving',
  });
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) showRidoSnack(context, 'Could not open Google Maps');
}

/// Opens a `upi://pay` link in the phone's UPI app (GPay, PhonePe, Paytm, BHIM…).
Future<void> openUpi(BuildContext context, Uri uri) async {
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) showRidoSnack(context, 'No UPI app found. Scan the QR code from another phone');
}
