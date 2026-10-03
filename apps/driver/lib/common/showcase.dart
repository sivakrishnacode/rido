import 'package:flutter/widgets.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

/// What a button says in a design gallery frame.
const kPreviewNote = 'Design preview: this button does nothing here';

/// Design gallery frames (the gallery is in every build) show a screen with seed data. Their buttons must not sign in,
/// save, pay, dial, open the camera, change the session or leave the gallery: in a frame ([showcase]) [action] is
/// replaced by a note. Null stays null (a disabled button stays disabled).
VoidCallback? unlessShowcase(BuildContext context, bool showcase, VoidCallback? action) {
  if (action == null || !showcase) return action;
  return () => showTtSnack(context, kPreviewNote);
}
