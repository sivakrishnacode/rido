import 'package:flutter/material.dart';
import 'package:rido_ui/rido_ui.dart';

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
        backgroundColor: RidoColors.background,
        appBar: RidoAppBar.driver(title: title, showBack: true),
        body: Column(children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.xl, RidoSpacing.gutter, RidoSpacing.l),
                    children: children,
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(RidoSpacing.gutter, RidoSpacing.s, RidoSpacing.gutter, RidoSpacing.l),
              child: RidoButton(label: 'Save', loading: saving, onPressed: loading ? null : onSave),
            ),
          ),
        ]),
      );
}
