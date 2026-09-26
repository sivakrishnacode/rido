import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_ui/rido_ui.dart';

import '../../common/launch.dart';

/// Account › Contribute: Rido is free (0% commission, no subscription); drivers and riders can chip in by UPI.
class ContributeScreen extends ConsumerWidget {
  const ContributeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(appConfigProvider).value?.contribute;
    return Scaffold(
      appBar: const RidoAppBar(
        title: 'Contribute',
        bottom: PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: ContributeView(
        info: info,
        onPay: (amount) => openUpi(context, info!.payUri(amountInr: amount)),
      ),
    );
  }
}
