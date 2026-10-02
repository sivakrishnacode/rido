import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

/// Emergency contact of the signed-in driver ("Lakshmi (Wife)" on D-26 and the SOS screen).
final driverEmergencyContactProvider = FutureProvider<EmergencyContact>((ref) {
  ref.watch(mockDatabaseProvider);
  return ref.watch(driverRepositoryProvider).emergencyContact();
});

/// The name D-06 saves with the emergency contact's number (sign-up asks only for the number).
const kSignupContactName = 'Emergency contact';

/// True for the contact saved at sign-up, before the driver named it.
bool isSignupContact(EmergencyContact c) => c.name.trim() == kSignupContactName;

/// "+919894066123" → "+91 98940 66123" (other numbers unchanged).
String formatContactPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  final ten = digits.length == 12 && digits.startsWith('91') ? digits.substring(2) : (digits.length == 10 ? digits : null);
  return ten == null ? phone : '+91 ${ten.substring(0, 5)} ${ten.substring(5)}';
}

/// How D-26 and SOS show the contact: "Lakshmi (Wife)"; the one saved at sign-up shows its number ("Family · +91 98940
/// 66123"); empty when there is none.
String emergencyContactLabel(EmergencyContact c) {
  if (c.name.isEmpty && c.phone.isEmpty) return '';
  if (isSignupContact(c) || c.name.isEmpty) {
    final number = formatContactPhone(c.phone);
    return c.relation.isEmpty ? number : '${c.relation} · $number';
  }
  final first = c.name.split(' ').first;
  return c.relation.isEmpty ? first : '$first (${c.relation})';
}
