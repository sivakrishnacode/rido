import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:rido_data/rido_data.dart';

import '../format.dart';
import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';
import 'choice_chips.dart';
import 'rido_button.dart';
import 'rido_card.dart';
import 'section_label.dart';
import 'skeleton_box.dart';
import 'status_pill.dart';

/// Icon for a help topic.
IconData helpTopicIcon(String topic) => switch (topic) {
      'Lost item' => Symbols.luggage_rounded,
      'Driver behaviour' || 'Rider behaviour' => Symbols.sentiment_dissatisfied_rounded,
      'Fare issue' || 'Payment issue' => Symbols.currency_rupee_rounded,
      'Parcel issue' => Symbols.deployed_code_rounded,
      'App problem' => Symbols.bug_report_rounded,
      'Safety concern' => Symbols.shield_rounded,
      'Plan & Autopay' => Symbols.workspace_premium_rounded,
      'Documents / KYC' => Symbols.badge_rounded,
      _ => Symbols.help_rounded,
    };

/// A trip shortcut shown on the help screens ("Gandhipuram → Brookefields · Today, 3:28 PM · ₹38").
class SupportTripRef {
  const SupportTripRef({required this.id, required this.title, required this.subtitle, required this.icon});
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}

/// P-25 Help & support body (shared by both apps): search, recent trip, topic grid,
/// "My tickets", and the WhatsApp / Raise a ticket buttons.
class SupportHomeView extends StatefulWidget {
  const SupportHomeView({
    super.key,
    required this.topics,
    required this.tickets,
    required this.onTopic,
    required this.onRaiseTicket,
    required this.onWhatsApp,
    this.recentTrip,
    this.onRecentTrip,
  });

  final List<String> topics;

  /// Null while loading.
  final List<SupportTicket>? tickets;
  final ValueChanged<String> onTopic;
  final VoidCallback onRaiseTicket;
  final VoidCallback onWhatsApp;
  final SupportTripRef? recentTrip;
  final VoidCallback? onRecentTrip;

  @override
  State<SupportHomeView> createState() => _SupportHomeViewState();
}

class _SupportHomeViewState extends State<SupportHomeView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final topics = widget.topics.where((x) => x.toLowerCase().contains(_query.toLowerCase())).toList();
    return Column(
      children: [
        Container(
          color: RidoColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Search help topics',
              prefixIcon: Icon(Symbols.search_rounded, color: RidoColors.navy700),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (widget.recentTrip != null && _query.isEmpty) ...[
                const SectionLabel('Recent trip'),
                RidoCard(
                  onTap: widget.onRecentTrip,
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: RidoColors.coral50, borderRadius: RidoRadii.cardRadius),
                      child: Icon(widget.recentTrip!.icon, color: RidoColors.coral500, fill: 1),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.recentTrip!.title, style: t.bodySemibold, overflow: TextOverflow.ellipsis),
                        Text(widget.recentTrip!.subtitle, style: t.bodySmall.copyWith(color: RidoColors.navy500)),
                      ]),
                    ),
                    Text('Get help', style: t.bodySemibold.copyWith(color: RidoColors.coral600)),
                  ]),
                ),
              ],
              const SectionLabel('Topics'),
              if (topics.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('No topics match "$_query". Raise a ticket and we will help.', style: t.bodySmall),
                ),
              LayoutBuilder(builder: (context, c) {
                final w = (c.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final topic in topics)
                      SizedBox(
                        width: w,
                        child: RidoCard(
                          onTap: () => widget.onTopic(topic),
                          color: topic == 'Safety concern' ? RidoColors.errorTint : RidoColors.surface,
                          borderColor: topic == 'Safety concern' ? const Color(0xFFFECACA) : RidoColors.divider,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                          child: Row(children: [
                            Icon(helpTopicIcon(topic),
                                color: topic == 'Safety concern' ? RidoColors.error : RidoColors.navy700),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(topic,
                                  style: t.bodyMedium.copyWith(
                                      color: topic == 'Safety concern' ? RidoColors.error : RidoColors.navy900)),
                            ),
                          ]),
                        ),
                      ),
                  ],
                );
              }),
              const SectionLabel('My tickets'),
              if (widget.tickets == null)
                const SkeletonBox(height: 72, radius: 12)
              else if (widget.tickets!.isEmpty)
                Text('No tickets yet.', style: t.bodySmall)
              else
                for (final tk in widget.tickets!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RidoCard(
                      padding: const EdgeInsets.all(16),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('${tk.topic} · #${tk.id}'),
                          content: Text('${tk.description}\n\nStatus: ${tk.status.label}. We usually reply within 24 hours.'),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                        ),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${tk.topic} · ${formatShortDate(tk.createdAt)}', style: t.bodySemibold),
                            Text(
                              '#${tk.id} · ${tk.status == TicketStatus.open ? 'Raised just now' : 'Updated 2h ago'}',
                              style: t.bodySmall.copyWith(color: RidoColors.navy500),
                            ),
                          ]),
                        ),
                        StatusPill(tk.status == TicketStatus.inProgress
                            ? StatusKind.inProgress
                            : tk.status == TicketStatus.open
                                ? StatusKind.open
                                : StatusKind.completed,
                            label: tk.status.label),
                      ]),
                    ),
                  ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(children: [
              Expanded(
                child: RidoButton.secondary(
                  label: 'Chat on WhatsApp',
                  icon: Symbols.chat_rounded,
                  onPressed: widget.onWhatsApp,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: RidoButton(label: 'Raise a ticket', onPressed: widget.onRaiseTicket)),
            ]),
          ),
        ),
      ],
    );
  }
}

/// P-25b "Raise a ticket" body (shared by both apps).
class NewTicketView extends StatefulWidget {
  const NewTicketView({
    super.key,
    required this.topics,
    required this.onSubmit,
    this.initialTopic,
    this.trip,
    this.onChangeTrip,
  });

  final List<String> topics;
  final String? initialTopic;
  final SupportTripRef? trip;
  final VoidCallback? onChangeTrip;

  /// Called with (topic, description). The view shows a loading button until it completes.
  final Future<void> Function(String topic, String description) onSubmit;

  @override
  State<NewTicketView> createState() => _NewTicketViewState();
}

class _NewTicketViewState extends State<NewTicketView> {
  late String? _topic = widget.initialTopic ?? (widget.trip != null ? 'Fare issue' : null);
  final _text = TextEditingController();
  bool _photo = false;
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final canSubmit = _topic != null && _text.text.trim().length >= 5 && !_sending;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            children: [
              Text('Topic', style: t.bodyMedium.copyWith(color: RidoColors.navy700)),
              const SizedBox(height: 10),
              ChoiceChips<String>(
                options: widget.topics,
                labelOf: (x) => x,
                selected: {?_topic},
                onChanged: (x) => setState(() => _topic = x),
              ),
              if (widget.trip != null) ...[
                const SizedBox(height: 20),
                Text('Trip', style: t.bodyMedium.copyWith(color: RidoColors.navy700)),
                const SizedBox(height: 10),
                RidoCard(
                  color: RidoColors.coral50,
                  borderColor: RidoColors.coral100,
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: RidoColors.surface, borderRadius: RidoRadii.cardRadius),
                      child: Icon(widget.trip!.icon, color: RidoColors.coral500, fill: 1),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.trip!.title, style: t.bodySemibold, overflow: TextOverflow.ellipsis),
                        Text(widget.trip!.subtitle, style: t.bodySmall.copyWith(color: RidoColors.navy500)),
                      ]),
                    ),
                    if (widget.onChangeTrip != null)
                      TextButton(onPressed: widget.onChangeTrip, child: const Text('Change')),
                  ]),
                ),
              ],
              const SizedBox(height: 20),
              Text('What happened?', style: t.bodyMedium.copyWith(color: RidoColors.navy700)),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('ticket-description'),
                controller: _text,
                maxLines: 4,
                maxLength: 500,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Tell us what went wrong'),
              ),
              const SizedBox(height: 8),
              RidoCard(
                color: RidoColors.background,
                onTap: () => setState(() => _photo = !_photo),
                child: Row(children: [
                  Icon(_photo ? Symbols.check_circle_rounded : Symbols.add_a_photo_rounded,
                      color: _photo ? RidoColors.success : RidoColors.coral600, fill: _photo ? 1 : 0),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: _photo ? 'Screenshot added' : 'Add a photo or screenshot ', style: t.bodyMedium),
                      if (!_photo) TextSpan(text: '(optional)', style: t.body.copyWith(color: RidoColors.navy500)),
                    ])),
                  ),
                ]),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(children: [
              RidoButton(
                label: 'Submit ticket',
                loading: _sending,
                onPressed: canSubmit
                    ? () async {
                        setState(() => _sending = true);
                        await widget.onSubmit(_topic!, _text.text.trim());
                        if (mounted) setState(() => _sending = false);
                      }
                    : null,
              ),
              const SizedBox(height: 8),
              Text('We usually reply within 24 hours', style: t.caption),
            ]),
          ),
        ),
      ],
    );
  }
}
