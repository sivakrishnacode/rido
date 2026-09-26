import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';

void main() {
  test('parses GET /app-config with the monthly cost and its breakdown', () {
    final c = AppConfig.fromJson({
      'driverPlansEnabled': false,
      'supportPhone': '+91 422 111 2222',
      'contribute': {
        'upiId': 'rido@okaxis',
        'payeeName': 'Rido',
        'note': 'Keep Rido free',
        'monthlyCost': {
          'totalInr': 6000,
          'items': [
            {'label': 'Servers & database', 'amountInr': 2500},
            {'label': 'Maps', 'amountInr': 3500},
          ],
        },
      },
    });
    expect(c.driverPlansEnabled, isFalse);
    expect(c.contribute.canPay, isTrue);
    expect(c.contribute.monthlyCostInr, 6000);
    expect(c.contribute.costItems.map((i) => '${i.label}=${i.amountInr}'), ['Servers & database=2500', 'Maps=3500']);
  });

  test('no UPI ID or cost entered: no pay button, cost hidden, default name and note', () {
    final c = AppConfig.fromJson({
      'driverPlansEnabled': true,
      'contribute': {'upiId': '', 'payeeName': '', 'note': '', 'monthlyCost': null},
    });
    expect(c.driverPlansEnabled, isTrue);
    expect(c.contribute.canPay, isFalse);
    expect(c.contribute.monthlyCostInr, isNull);
    expect(c.contribute.payeeName, 'Rido');
    expect(c.contribute.note, AppConfig.defaultNote);
  });

  test('UPI link encodes spaces as %20 and adds the amount only when chosen', () {
    const info = ContributeInfo(upiId: 'rido@okaxis', payeeName: 'Rido Coimbatore', note: '');
    expect(info.payUri(amountInr: 50).toString(),
        'upi://pay?pa=rido@okaxis&pn=Rido%20Coimbatore&am=50&cu=INR&tn=Contribution%20to%20Rido%20Coimbatore');
    expect(info.payUri().queryParameters.containsKey('am'), isFalse);
  });
}
