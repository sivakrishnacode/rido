import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tamiltaxi_ui/tamiltaxi_ui.dart';

import '../../router/routes.dart';
import 'gallery_registry.dart';

/// "Screens" tab: search by ID or name, grouped by part.
class GalleryScreensTab extends StatefulWidget {
  const GalleryScreensTab({super.key});

  @override
  State<GalleryScreensTab> createState() => _GalleryScreensTabState();
}

class _GalleryScreensTabState extends State<GalleryScreensTab> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _matches(GalleryEntry e) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return e.id.toLowerCase().contains(q) ||
        e.id.toLowerCase().replaceAll('-', '').contains(q.replaceAll('-', '')) ||
        e.name.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final filtered = galleryEntries.where(_matches).toList();
    final parts = <String, List<GalleryEntry>>{};
    for (final e in filtered) {
      parts.putIfAbsent(e.part, () => []).add(e);
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(TtSpacing.gutter, TtSpacing.m, TtSpacing.gutter, 0),
          child: SearchField(
            hint: 'Search by ID or name',
            controller: _controller,
            leadingIcon: Symbols.search_rounded,
            leadingColor: TtColors.navy500,
            showMic: false,
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(TtSpacing.xl),
                    child: Text(
                      'No frames match "$_query"',
                      style: t.body.copyWith(color: TtColors.navy500),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(TtSpacing.gutter, 0, TtSpacing.gutter, TtSpacing.xxl),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: TtSpacing.m),
                      child: Text(
                        '${filtered.length} of ${galleryEntries.length} frames',
                        style: t.caption.copyWith(color: TtColors.navy500),
                      ),
                    ),
                    for (final part in parts.entries) ...[
                      SectionLabel(part.key.toUpperCase()),
                      TtListGroup(children: [for (final e in part.value) _FrameRow(entry: e)]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _FrameRow extends StatelessWidget {
  const _FrameRow({required this.entry});
  final GalleryEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final showcaseOnly = entry.tag == GalleryTag.showcaseOnly;
    return Semantics(
      button: true,
      label: '${entry.id} ${entry.name}, ${entry.tag.label}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push(Routes.galleryView(entry.id)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: TtSpacing.m, vertical: TtSpacing.s),
            child: Row(
              children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 64),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: TtColors.coral50, borderRadius: TtRadii.pillRadius),
                  child: Text(
                    entry.id,
                    maxLines: 1,
                    style: TtTextStyles.tabular(t.caption.copyWith(color: TtColors.coral600, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: TtSpacing.m),
                Expanded(
                  child: Text(entry.name, style: t.bodySmallMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: TtSpacing.s),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: showcaseOnly ? TtColors.warningTint : TtColors.successTint,
                    borderRadius: TtRadii.pillRadius,
                  ),
                  child: Text(
                    entry.tag.label,
                    style: t.caption.copyWith(
                      color: showcaseOnly ? TtColors.warningText : TtColors.successText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: TtSpacing.xs),
                const Icon(Symbols.chevron_right_rounded, size: 20, color: TtColors.navy500),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A group of demo controls under a label.
class DemoGroup extends StatelessWidget {
  const DemoGroup({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [SectionLabel(title.toUpperCase()), TtListGroup(children: children)],
      );
}

/// One demo switch with a one-line explanation.
class DemoSwitchTile extends StatelessWidget {
  const DemoSwitchTile({
    super.key,
    required this.title,
    required this.explanation,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  final String title;
  final String explanation;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: TtSpacing.m, vertical: TtSpacing.s),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: TtColors.navy700),
                const SizedBox(width: TtSpacing.m),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.bodyMedium),
                    Text(explanation, style: t.caption.copyWith(color: TtColors.navy500)),
                  ],
                ),
              ),
              const SizedBox(width: TtSpacing.s),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// A demo control with a custom trailing/bottom control (segmented).
class DemoChoiceTile extends StatelessWidget {
  const DemoChoiceTile({super.key, required this.title, required this.explanation, required this.child, this.icon});

  final String title;
  final String explanation;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.all(TtSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: TtColors.navy700),
                const SizedBox(width: TtSpacing.m),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.bodyMedium),
                    Text(explanation, style: t.caption.copyWith(color: TtColors.navy500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TtSpacing.m),
          child,
        ],
      ),
    );
  }
}
