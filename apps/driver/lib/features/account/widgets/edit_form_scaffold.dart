import 'package:flutter/material.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

/// Simple account edit screen: navy app bar, scrolling fields and a pinned Save button.
class EditFormScaffold extends StatelessWidget {
  const EditFormScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    this.saving = false,
    this.loading = false,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onSave;
  final bool saving;
  final bool loading;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TtColors.background,
        appBar: TtAppBar.driver(title: title, showBack: true),
        body: Column(children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(TtSpacing.gutter, TtSpacing.xl, TtSpacing.gutter, TtSpacing.l),
                    children: children,
                  ),
          ),
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
