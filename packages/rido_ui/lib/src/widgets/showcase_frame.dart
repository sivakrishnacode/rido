import 'package:flutter/material.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';
import 'map_bottom_sheet.dart';

/// Design gallery helper: shows a bottom sheet's or dialog's content over a plain
/// background, exactly as it looks when opened in the flow.
class ShowcaseFrame extends StatelessWidget {
  const ShowcaseFrame.sheet({super.key, required this.child, this.title}) : dialog = false;
  const ShowcaseFrame.dialog({super.key, required this.child, this.title}) : dialog = true;

  final Widget child;
  final bool dialog;

  /// Optional frame label shown at the top ("P-11 Fare details").
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RidoColors.scrim,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: title == null ? null : Text(title!, style: context.type.h2.copyWith(color: Colors.white)),
      ),
      body: dialog
          ? Center(child: child)
          : Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: RidoColors.surface,
                borderRadius: RidoRadii.sheetTop,
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [const SheetHandle(), child],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
