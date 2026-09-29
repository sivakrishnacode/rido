import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../../state/request_voice.dart';

/// Speaker button on the request header: turns reading requests aloud on or off (saved on the phone).
class RequestVoiceToggle extends ConsumerWidget {
  const RequestVoiceToggle({super.key, this.dark = true});

  /// On the coral header (white icon); false on a light background.
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(requestVoiceProvider.select((s) => s.enabled));
    return IconButton(
      tooltip: on ? 'Voice on. Tap to mute' : 'Voice off. Tap to read requests aloud',
      onPressed: () => ref.read(requestVoiceProvider.notifier).setEnabled(!on),
      style: IconButton.styleFrom(backgroundColor: dark ? TtColors.coral700 : TtColors.inputBg),
      icon: Icon(on ? Symbols.volume_up_rounded : Symbols.volume_off_rounded,
          color: dark ? Colors.white : TtColors.navy900, fill: 1),
    );
  }
}
