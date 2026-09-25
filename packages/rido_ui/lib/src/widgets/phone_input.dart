import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';

/// Formats 10 digits as "98765 43210".
class _IndianPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final d = digits.substring(0, math.min(10, digits.length));
    final text = d.length > 5 ? '${d.substring(0, 5)} ${d.substring(5)}' : d;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Phone number input with a fixed "+91" prefix. [onChanged] receives digits only.
class PhoneInput extends StatelessWidget {
  const PhoneInput({
    super.key,
    this.controller,
    this.onChanged,
    this.errorText,
    this.label = 'Mobile number',
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final String? label;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  /// Strips spaces: "98765 43210" → "9876543210".
  static String digitsOf(String text) => text.replaceAll(RegExp(r'\D'), '');

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: t.bodySmallMedium.copyWith(color: RidoColors.navy700)),
          const SizedBox(height: 6),
        ],
        TextField(
          key: const ValueKey('phone-input'),
          controller: controller,
          autofocus: autofocus,
          keyboardType: TextInputType.phone,
          inputFormatters: [_IndianPhoneFormatter()],
          onChanged: (v) => onChanged?.call(digitsOf(v)),
          onSubmitted: onSubmitted,
          style: RidoTextStyles.tabular(t.bodyMedium.copyWith(fontSize: 18, letterSpacing: 0.5)),
          decoration: InputDecoration(
            hintText: '98765 43210',
            errorText: errorText,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('+91', style: t.bodyMedium.copyWith(fontSize: 18)),
                  const SizedBox(width: 12),
                  Container(width: 1, height: 24, color: RidoColors.divider),
                ],
              ),
            ),
            suffixIcon: errorText != null ? const Icon(Symbols.error_rounded, color: RidoColors.error) : null,
          ),
        ),
      ],
    );
  }
}
