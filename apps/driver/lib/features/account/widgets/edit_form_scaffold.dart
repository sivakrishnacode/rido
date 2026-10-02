import 'package:flutter/material.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../../common/load_error.dart';

/// Simple account edit screen: navy app bar, scrolling fields and a pinned Save button. While [loading] the fields
/// wait (spinner) and when [error] is set they're replaced by a Retry state; Save is off in both cases.
class EditFormScaffold extends StatelessWidget {
  const EditFormScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    this.saving = false,
    this.loading = false,
    this.error,
    this.onRetry,
    this.what = 'this',
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onSave;
  final bool saving;
  final bool loading;

  /// What failed to load (see [LoadError]); [onRetry] loads it again.
  final Object? error;
  final VoidCallback? onRetry;
  final String what;

  @override
  Widget build(BuildContext context) {
    final failed = error;
    return Scaffold(
      backgroundColor: TtColors.background,
      appBar: TtAppBar.driver(title: title, showBack: true),
      body: Column(children: [
        Expanded(
          child: failed != null
              ? LoadError(error: failed, onRetry: onRetry ?? () {}, what: what)
              : loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(TtSpacing.gutter, TtSpacing.xl, TtSpacing.gutter, TtSpacing.l),
                      children: children,
                    ),
        ),
        if (failed == null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(TtSpacing.gutter, TtSpacing.s, TtSpacing.gutter, TtSpacing.l),
              child: TtButton(label: 'Save', loading: saving, onPressed: loading ? null : onSave),
            ),
          ),
      ]),
    );
  }
}
