import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tt_colors.dart';
import '../theme/tt_tokens.dart';

/// A 4- or 6-box OTP input. Boxes are drawn over one hidden text field, so paste and
/// the system keyboard work normally. Increment [shakeTrigger] to play the error shake.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
    this.hasError = false,
    this.shakeTrigger = 0,
    this.autofocus = true,
    this.initialValue = '',
    this.boxSize,
  }) : assert(length == 4 || length == 6);

  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool hasError;
  final int shakeTrigger;
  final bool autofocus;
  final String initialValue;

  /// Defaults to 64 for 4 boxes and fits the width for 6.
  final double? boxSize;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> with SingleTickerProviderStateMixin {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue);
  final FocusNode _focus = FocusNode();
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(OtpInput old) {
    super.didUpdateWidget(old);
    if (widget.shakeTrigger != old.shakeTrigger) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final value = _controller.text;
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final dx = math.sin(_shake.value * math.pi * 6) * 10 * (1 - _shake.value);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: LayoutBuilder(builder: (context, c) {
        const gap = 10.0;
        final fit = (c.maxWidth - gap * (widget.length - 1)) / widget.length;
        final size = math.min(widget.boxSize ?? (widget.length == 4 ? 64 : 52), fit);
        return Stack(
          children: [
            // Hidden field that owns input.
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  key: const ValueKey('otp-field'),
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  maxLength: widget.length,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(counterText: '', border: InputBorder.none, filled: false),
                  onChanged: (v) {
                    setState(() {});
                    widget.onChanged?.call(v);
                    if (v.length == widget.length) widget.onCompleted?.call(v);
                  },
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _focus.requestFocus();
                SystemChannels.textInput.invokeMethod<void>('TextInput.show');
              },
              child: Semantics(
                label: 'OTP, ${widget.length} digits, ${value.length} entered',
                textField: true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < widget.length; i++)
                      _box(
                        t,
                        size,
                        i < value.length ? value[i] : '',
                        focused: _focus.hasFocus && i == math.min(value.length, widget.length - 1),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _box(TtTextStyles t, double size, String digit, {required bool focused}) {
    final borderColor = widget.hasError
        ? TtColors.error
        : focused
            ? TtColors.coral600
            : digit.isEmpty
                ? Colors.transparent
                : TtColors.divider;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size,
      height: size * 1.08,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: digit.isEmpty && !focused && !widget.hasError ? TtColors.inputBg : TtColors.surface,
        borderRadius: TtRadii.cardRadius,
        border: Border.all(color: borderColor, width: focused || widget.hasError ? 2 : 1),
      ),
      child: focused && digit.isEmpty
          ? Container(width: 2, height: size * 0.4, color: TtColors.coral600)
          : Text(digit, style: TtTextStyles.tabular(t.h1.copyWith(fontSize: size * 0.42))),
    );
  }
}
