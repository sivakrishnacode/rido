
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

/// Search field with a coral location icon and an optional mic. In [readOnly] mode the
/// whole field is a button that calls [onTap] (P-07 "Where are you going?").
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.autofocus = false,
    this.leadingIcon = Symbols.location_on_rounded,
    this.leadingColor = RidoColors.coral500,
    this.showMic = true,
    this.large = false,
    this.focusNode,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autofocus;
  final IconData leadingIcon;
  final Color leadingColor;
  final bool showMic;

  /// Large variant (P-07): 56px tall, H2-sized hint.
  final bool large;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final style = large ? t.h2.copyWith(fontWeight: FontWeight.w500) : t.body;
    return Semantics(
      button: readOnly,
      label: readOnly ? hint : null,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onTap: onTap,
        readOnly: readOnly,
        autofocus: autofocus,
        focusNode: focusNode,
        style: style,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: style.copyWith(color: large ? RidoColors.navy900 : RidoColors.navy500),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: large ? 16 : 12),
          prefixIcon: Icon(leadingIcon, color: leadingColor, fill: 1, size: large ? 28 : 24),
          suffixIcon: showMic
              ? IconButton(
                  tooltip: 'Voice search',
                  onPressed: () => ScaffoldMessenger.maybeOf(context)
                    ?..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(content: Text('Listening… say a place name'))),
                  icon: const Icon(Symbols.mic_rounded, color: RidoColors.navy500),
                )
              : null,
        ),
      ),
    );
  }
}
