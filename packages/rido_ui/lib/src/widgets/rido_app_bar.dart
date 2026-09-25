import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';
import 'rido_wordmark.dart';

/// Top app bar. Passenger style: white, 64px, back arrow + H2 title.
/// [RidoAppBar.driver] is navy-900 with the wordmark (or a title) and light icons.
class RidoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const RidoAppBar({
    super.key,
    this.title,
    this.actions,
    this.showBack = true,
    this.onBack,
    this.bottom,
    this.subtitle,
    this.backIcon = Symbols.arrow_back_rounded,
  }) : dark = false,
       showWordmark = false;

  const RidoAppBar.driver({
    super.key,
    this.title,
    this.actions,
    this.showBack = false,
    this.onBack,
    this.bottom,
    this.subtitle,
    this.showWordmark = false,
    this.backIcon = Symbols.arrow_back_rounded,
  }) : dark = true;

  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;
  final bool dark;
  final bool showWordmark;
  final IconData backIcon;

  @override
  Size get preferredSize => Size.fromHeight(64 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final fg = dark ? Colors.white : RidoColors.navy900;
    return AppBar(
      backgroundColor: dark ? RidoColors.navy900 : RidoColors.surface,
      foregroundColor: fg,
      systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      automaticallyImplyLeading: false,
      titleSpacing: showBack ? 0 : 16,
      leading: showBack
          ? IconButton(
              tooltip: 'Back',
              icon: Icon(backIcon, color: fg),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null,
      title: showWordmark
          ? const RidoWordmark(size: 26, color: Colors.white)
          : title == null
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title!, style: t.h2.copyWith(color: fg), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (subtitle != null)
                      Text(subtitle!, style: t.caption.copyWith(color: dark ? Colors.white70 : RidoColors.navy500)),
                  ],
                ),
      actions: [...?actions, const SizedBox(width: 4)],
      bottom: bottom,
    );
  }
}
