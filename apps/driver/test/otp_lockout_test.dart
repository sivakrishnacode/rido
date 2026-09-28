// Too many wrong OTPs (429 OTP_LOCKED): the OTP screens keep their button off for details.retryInSeconds.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_driver/features/jobs/widgets/otp_step.dart';

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with OtpLockout<_Probe> {
  @override
  Widget build(BuildContext context) => Text(isOtpLocked ? 'locked' : 'open', textDirection: TextDirection.ltr);
}

void main() {
  testWidgets('locks for retryInSeconds, only on OTP_LOCKED', (tester) async {
    await tester.pumpWidget(const _Probe());
    final state = tester.state<_ProbeState>(find.byType(_Probe));

    expect(state.lockIfOtpLocked(const ApiException(400, 'Wrong OTP, please try again', code: 'WRONG_OTP')), isFalse);
    expect(state.isOtpLocked, isFalse);

    const locked = ApiException(429, 'Too many wrong OTPs', code: 'OTP_LOCKED', details: {'retryInSeconds': 30});
    expect(state.lockIfOtpLocked(locked), isTrue);
    expect(state.isOtpLocked, isTrue);

    await tester.pump(const Duration(seconds: 31));
    expect(state.isOtpLocked, isFalse);
    expect(find.text('open'), findsOneWidget);
  });
}
