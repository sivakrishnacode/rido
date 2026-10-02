import 'package:flutter_test/flutter_test.dart';
import 'package:tamiltaxi_data/tamiltaxi_data.dart';

void main() {
  test('initials never throw on a blank name', () {
    expect(Seed.karthik.copyWith(name: '  ').initials, '?');
    expect(Seed.karthik.copyWith(name: 'Karthik  Selvam').initials, 'KS');
    expect(Seed.karthik.copyWith(name: 'Karthik').initials, 'K');
  });
}
