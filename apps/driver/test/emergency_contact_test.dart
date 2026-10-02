// The emergency contact saved at sign-up has only a number: D-26 and SOS show the number, not "Emergency (Family)",
// and the edit form starts with an empty name.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';
import 'package:tamiltaxi_driver/features/account/account_providers.dart';
import 'package:tamiltaxi_driver/features/account/driver_emergency_contact_screen.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import 'support/harness.dart';

const _signup = EmergencyContact(id: 'c1', name: kSignupContactName, relation: 'Family', phone: '+919894066123');

class _Repo implements DriverRepository {
  @override
  Future<EmergencyContact> emergencyContact() async => _signup;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('labels', () {
    expect(emergencyContactLabel(_signup), 'Family · +91 98940 66123');
    expect(emergencyContactLabel(const EmergencyContact(id: '', name: kSignupContactName, relation: '', phone: '+919894066123')),
        '+91 98940 66123');
    expect(emergencyContactLabel(const EmergencyContact(id: '', name: 'Lakshmi Devi', relation: 'Wife', phone: '9894066123')),
        'Lakshmi (Wife)');
    expect(emergencyContactLabel(const EmergencyContact(id: '', name: '', relation: '', phone: '')), '');
  });

  testWidgets('editing the sign-up contact starts with an empty name and the number', (tester) async {
    await loadTestFonts();
    usePhone(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [driverRepositoryProvider.overrideWithValue(_Repo())],
      child: MaterialApp(theme: TtTheme.light(), home: const DriverEmergencyContactScreen()),
    ));
    await tester.pump();
    await tester.pump();
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.first.controller!.text, '');
    expect(fields.any((f) => f.controller!.text.contains('98940')), isTrue);
  });
}
