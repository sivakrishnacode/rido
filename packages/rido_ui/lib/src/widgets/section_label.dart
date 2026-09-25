import 'package:flutter/material.dart';

import '../theme/rido_tokens.dart';

/// Upper-case section label ("RECENT TRIP", "PAYMENT HISTORY") with an optional trailing action.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(0, 20, 0, 10)});

  final String text;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(child: Text(text.toUpperCase(), style: context.type.overline)),
            ?trailing,
          ],
        ),
      );
}
