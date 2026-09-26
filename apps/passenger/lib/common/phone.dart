import 'package:rido_data/rido_data.dart';

/// "+91 98765 43210" for display, whichever way the number was stored ("+919876543210" from the API,
/// "98765 43210" typed, or the formatted seed values). Numbers going to the API use rido_data's `apiPhone`.
String displayPhone(String phone) {
  final api = apiPhone(phone);
  if (!api.startsWith('+91') || api.length != 13) return phone;
  return '+91 ${api.substring(3, 8)} ${api.substring(8)}';
}
